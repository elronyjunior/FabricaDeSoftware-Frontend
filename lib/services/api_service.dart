import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fabrica_software_app/config/api_config.dart';
import 'package:fabrica_software_app/services/auth_service.dart';
import 'package:fabrica_software_app/services/base_api_service.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';

class ApiService {
  
  // ===========================================================================
  //                              HELPERS
  // ===========================================================================

  // Converte IDs que vêm como String ("8") do Postgres para Int (8)
  static int _parseId(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Deixa o valor no formato dos enums do banco (minúsculas, sem acento):
  /// a tela usa "Média"/"Crítica", mas o Postgres só aceita "media"/"critica".
  /// Valor fora da lista vira [padrao].
  static String _normalizarEnum(
      dynamic valor, Set<String> permitidos, String padrao) {
    if (valor == null) return padrao;
    const acentos = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e',
      'í': 'i', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ú': 'u', 'ç': 'c',
    };
    final texto = valor
        .toString()
        .trim()
        .toLowerCase()
        .split('')
        .map((c) => acentos[c] ?? c)
        .join();
    return permitidos.contains(texto) ? texto : padrao;
  }

  static const _prioridadesRequisito = {'baixa', 'media', 'alta', 'critica'};
  static const _complexidadesProjeto = {'baixa', 'media', 'alta'};

  /// Token recusado (401, ou 403 "Token inválido ou expirado"): avisa o app
  /// e lança o erro de sessão expirada, como o BaseApiService.
  static void _conferirSessao(http.Response response) {
    if (BaseApiService.sessaoExpirou(response)) {
      BaseApiService.lancarSessaoExpirada();
    }
  }

  // Salva o token (Chame isso no Login se não estiver usando o AuthService para isso)
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Monta o Header com o Token de Autenticação correto
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    // ATENÇÃO: A chave deve ser a mesma usada no seu login ('auth_token')
    final String? token = prefs.getString('auth_token'); 
    
    if (token == null) {
      print("ALERTA: Token de autenticação não encontrado no SharedPreferences.");
    }

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Helper Genérico para GET
  static Future<List<dynamic>> _get(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders();
    
    try {
      final response = await http.get(uri, headers: headers);
      _conferirSessao(response);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Erro GET ${response.statusCode}: ${response.body}');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Falha na conexão ($endpoint): $e');
    }
  }

  // ===========================================================================
  //                              MÉTODOS DE IA
  // ===========================================================================

  static Future<List<dynamic>> gerarRequisitosBackend(String escopo, String nomeProjeto) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ai/gerar-requisitos');
    final headers = await _getHeaders();

    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          "escopo": escopo, 
          "nomeProjeto": nomeProjeto
        }),
      );

      if (response.statusCode == 200) {
        // Decodifica UTF8 para suportar acentos corretamente
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Erro na IA (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Falha de conexão com IA: $e');
    }
  }

  // Gera só o diagrama de casos de uso (Mermaid + SVG já renderizado) a
  // partir dos requisitos ainda em memória no wizard - não depende de
  // projeto salvo (sem projetoId). Retorna { titulo, atores, mermaid, svg,
  // aviso_renderizacao }; "svg" pode vir null se o backend não conseguiu
  // renderizar (nesse caso "aviso_renderizacao" explica o motivo e "mermaid"
  // ainda traz o código bruto).
  static Future<Map<String, dynamic>> gerarDiagramaCasoUso(
    String nomeProjeto,
    String? escopo,
    List<Map<String, dynamic>> requisitos,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ai/gerar-diagrama-caso-uso');
    final headers = await _getHeaders();

    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          "nomeProjeto": nomeProjeto,
          "escopo": escopo,
          "requisitos": requisitos,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Erro na IA (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Falha de conexão com IA: $e');
    }
  }

  // Chat com memória sobre a lista de requisitos - sem sessionId, começa uma
  // sessão nova; com sessionId, continua a conversa. Sempre manda a lista
  // atual de requisitos (a pessoa pode editar manualmente entre mensagens),
  // e volta a lista COMPLETA já atualizada + uma resposta curta da IA.
  static Future<Map<String, dynamic>> chatRequisitos({
    String? sessionId,
    required String mensagem,
    required String nomeProjeto,
    String? escopo,
    required List<Map<String, dynamic>> requisitosAtuais,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ai/chat-requisitos');
    final headers = await _getHeaders();

    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          "sessionId": sessionId,
          "mensagem": mensagem,
          "nomeProjeto": nomeProjeto,
          "escopo": escopo,
          "requisitosAtuais": requisitosAtuais,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        final erro = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(erro['error'] ?? 'Erro no chat de requisitos (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Falha de conexão com IA: $e');
    }
  }

  // Pede um ajuste específico sobre um diagrama já gerado (mesmo sessionId
  // devolvido por gerarDiagramaCasoUso) - o backend guarda o histórico da
  // conversa, então não precisa reenviar requisitos/instruções anteriores.
  static Future<Map<String, dynamic>> refinarDiagramaCasoUso(String sessionId, String instrucao) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ai/refinar-diagrama-caso-uso');
    final headers = await _getHeaders();

    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({"sessionId": sessionId, "instrucao": instrucao}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        final erro = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(erro['error'] ?? 'Erro ao refinar diagrama (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Falha de conexão com IA: $e');
    }
  }

  // Retorna Map com { "orcamento_estimado": double, "complexidade": string }
  static Future<Map<String, dynamic>> estimarOrcamentoBackend(Map<String, dynamic> dadosProjeto) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ai/estimar-orcamento');
    final headers = await _getHeaders();
    
    final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(dadosProjeto),
      );
    } catch (e) {
      print("Erro IA Orçamento: $e");
      throw Exception('Falha ao conectar com serviço de Orçamento: $e');
    }

    if (response.statusCode == 200) {
      // utf8 explícito: a complexidade e a justificativa vêm com acento.
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    // Repassa a resposta do servidor (ex.: limite de uso da IA) para a tela
    // poder explicar o motivo.
    throw Exception(
        'Erro na IA de Orçamento (${response.statusCode}): ${response.body}');
  }

  // ===========================================================================
  //                          SALVAR PROJETO COMPLETO
  // ===========================================================================

  /// Cria o projeto e os vínculos. O projeto não é desfeito se algum vínculo
  /// falhar: devolve a lista do que não foi vinculado (vazia = tudo certo) e
  /// já mostra o aviso no app, para a pessoa saber o que refazer.
  static Future<List<String>> criarProjetoCompleto(
      Map<String, dynamic> dtoData) async {
    // Sem usuário o id caía para 0 e o banco recusava (chave estrangeira):
    // melhor parar antes de criar qualquer coisa.
    final usuarioId = _parseId(dtoData['criado_por_id'] ??
        dtoData['responsavel_id'] ??
        await AuthService.instance.userId);
    if (usuarioId <= 0) {
      throw ApiException('Sessão expirada, entre de novo');
    }
    final criadoPorId = _parseId(dtoData['criado_por_id']) > 0
        ? _parseId(dtoData['criado_por_id'])
        : usuarioId;
    final responsavelId = _parseId(dtoData['responsavel_id']) > 0
        ? _parseId(dtoData['responsavel_id'])
        : criadoPorId;

    final headers = await _getHeaders();

    // 1. Criar Projeto Pai na tabela 'projetos'
    final uriProjeto = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.projetos}');

    // Use os valores passados em dtoData quando disponíveis. Mantém compatibilidade
    // com chaves antigas (`tipo`) caso o caller ainda as envie.
    final projetoPayload = {
      "nome_projeto": dtoData['nome_projeto'],
      "descricao": dtoData['descricao'],
      "modelo_projeto": dtoData['modelo_projeto'],
      // O back-end grava o campo "tipo" (aceita 'tipo_projeto' do caller).
      "tipo": dtoData['tipo_projeto'] ?? dtoData['tipo'],
      "escopo": dtoData['escopo'],
      // Enum complexidade_projeto: baixa|media|alta (sem acento).
      "complexidade": dtoData['complexidade'] == null
          ? null
          : _normalizarEnum(
              dtoData['complexidade'], _complexidadesProjeto, 'media'),
      "cliente_id": dtoData['cliente_id'],
      "metodologia": dtoData['metodologia'],
      "orcamento_estimado": dtoData['orcamento_estimado'],
      "data_inicio": dtoData['data_inicio'],
      "data_final_previsto": dtoData['data_final_previsto'],
      "criado_por_id": criadoPorId,
      "responsavel_id": responsavelId,
    };

    final respProj = await http.post(uriProjeto,
        headers: headers, body: jsonEncode(projetoPayload));
    _conferirSessao(respProj);

    if (respProj.statusCode != 201 && respProj.statusCode != 200) {
      throw Exception('Falha ao criar projeto: ${respProj.body}');
    }

    final projetoCriado = jsonDecode(respProj.body);
    final int projetoId = _parseId(projetoCriado['id']); // Converte ID string para int

    // 2. Vínculos Sequenciais (Pivot Tables). Cada um é conferido: antes as
    // falhas sumiam e o projeto ficava incompleto sem ninguém saber.
    final falhas = <String>[];

    // Faz o POST e anota [rotulo] em falhas se não voltar 2xx.
    Future<http.Response?> postVinculo(
        String endpoint, Map<String, dynamic> corpo, String rotulo) async {
      try {
        final resp = await http.post(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: headers,
          body: jsonEncode(corpo),
        );
        if (resp.statusCode >= 200 && resp.statusCode < 300) return resp;
        print('Falha ao vincular $rotulo (${resp.statusCode}): ${resp.body}');
      } catch (e) {
        print('Falha ao vincular $rotulo: $e');
      }
      falhas.add(rotulo);
      return null;
    }

    // a) Tecnologias
    if (dtoData['tecnologias'] != null) {
      for (var techId in (dtoData['tecnologias'] as List)) {
        await postVinculo(ApiConfig.tecnologiasProjeto, {
          "projeto_id": projetoId,
          "tecnologia_id": _parseId(techId),
          "data_aprovacao": DateTime.now().toIso8601String(),
          // quem criou o projeto aprova as tecnologias escolhidas
          "aprovado_por_id": criadoPorId,
        }, 'tecnologia #${_parseId(techId)}');
      }
    }

    // b) Equipe: as pessoas escolhidas são usuários (Gestão de usuários),
    // mas a equipe no banco aponta para `contribuidores`. Cada usuário vira
    // o contribuidor de mesmo e-mail (criado aqui se ainda não existir).
    final equipe = (dtoData['equipe'] as List?) ?? const [];
    if (equipe.isNotEmpty) {
      List<dynamic>? contribuidores;
      try {
        contribuidores = await _get(ApiConfig.contribuidores);
      } catch (e) {
        // Sem a lista não dá para vincular ninguém: vira falha de cada membro.
        print('Não foi possível ler os contribuidores: $e');
      }
      for (var membro in equipe) {
        final rotulo =
            'membro ${membro['nome'] ?? membro['email'] ?? ''}'.trim();
        int? contribuidorId;
        if (contribuidores != null) {
          try {
            contribuidorId =
                await _contribuidorDoMembro(membro, contribuidores, headers);
          } catch (e) {
            print('Falha ao preparar $rotulo: $e');
          }
        }
        if (contribuidorId == null || contribuidorId <= 0) {
          falhas.add(rotulo);
          continue;
        }
        await postVinculo(ApiConfig.contribuidoresProjeto, {
          "projeto_id": projetoId,
          "contribuidor_id": contribuidorId,
          "data_inicio": dtoData['data_inicio'],
          "data_fim": dtoData['data_final_previsto']
        }, rotulo);
      }
    }

    // c) Recursos
    if (dtoData['recursos'] != null) {
      for (var recId in (dtoData['recursos'] as List)) {
        await postVinculo(ApiConfig.recursosProjeto, {
          "projeto_id": projetoId,
          "recurso_id": _parseId(recId),
          "custo_hora": 0.0,
          "data_alocacao": dtoData['data_inicio'],
          "data_desalocacao": dtoData['data_final_previsto']
        }, 'recurso #${_parseId(recId)}');
      }
    }

    // d) Requisitos (Criação + Vínculo)
    if (dtoData['requisitos'] != null) {
      for (var req in (dtoData['requisitos'] as List)) {
        final rotulo =
            'requisito ${req['codigo'] ?? req['titulo'] ?? ''}'.trim();
        // Passo d1: Criar o requisito na tabela 'requisitos'
        final respReq = await postVinculo(ApiConfig.requisitos, {
          "tipo": req['tipo'],
          "descricao": "${req['titulo']}: ${req['descricao']}",
          "observacoes": "Gerado via App Mobile"
        }, rotulo);
        if (respReq == null) continue;

        final reqId = _parseId(jsonDecode(respReq.body)['id']);

        // Passo d2: Vincular na tabela 'requisitos_projeto'
        await postVinculo(ApiConfig.requisitosProjeto, {
          "projeto_id": projetoId,
          "requisito_id": reqId,
          // Enum prioridade_requisito: 'Média' da tela vira 'media'.
          "prioridade": _normalizarEnum(
              req['prioridade'], _prioridadesRequisito, 'media'),
          "codigo_requisito": req['codigo'] ??
              "REQ-${DateTime.now().millisecondsSinceEpoch}",
          "criado_por_id": criadoPorId
        }, rotulo);
      }
    }

    // e) Diagrama de Casos de Uso (gerado no wizard) - só salva se a pessoa
    // chegou a gerar um diagrama; não é obrigatório pra concluir o projeto.
    // Não bloqueia a criação, mas entra no aviso se falhar.
    final mermaid = dtoData['diagrama_caso_uso_mermaid'] as String?;
    if (mermaid != null && mermaid.trim().isNotEmpty) {
      await postVinculo('/documentos/diagrama-mermaid', {
        "projetoId": projetoId,
        "titulo": dtoData['diagrama_caso_uso_titulo'] ??
            "Diagrama de Casos de Uso - ${dtoData['nome_projeto']}",
        "mermaid": mermaid,
        "imagemBase64": dtoData['diagrama_caso_uso_imagem_base64'],
        "atores": dtoData['diagrama_caso_uso_atores'],
      }, 'diagrama de casos de uso');
    }

    // Aviso global (sem context): quem chama segue o fluxo de sucesso
    // normal e a pessoa vê o que não foi vinculado.
    if (falhas.isNotEmpty) {
      final itens = falhas.length == 1
          ? '1 item não foi vinculado'
          : '${falhas.length} itens não foram vinculados';
      avisarApp('Projeto criado, mas $itens: ${falhas.join(', ')}.',
          tipo: TipoAviso.info);
    }
    return falhas;
  }

  // ===========================================================================
  //                          GETTERS (DADOS DO BANCO)
  // ===========================================================================
  
  static Future<List<dynamic>> getClientes() async => _get(ApiConfig.clientes);
  static Future<List<dynamic>> getTecnologias() async => _get(ApiConfig.tecnologias);
  static Future<List<dynamic>> getContribuidores() async => _get(ApiConfig.contribuidores);

  /// Usuários do sistema (Gestão de usuários): as pessoas das equipes.
  static Future<List<dynamic>> getUsuarios() async => _get(ApiConfig.usuarios);

  /// Id do contribuidor de um membro da equipe (um usuário): o de mesmo
  /// e-mail, ou um novo criado com os dados do usuário. Membros sem e-mail
  /// (rascunhos antigos) já são contribuidores: usa o id deles.
  static Future<int?> _contribuidorDoMembro(dynamic membro,
      List<dynamic> contribuidores, Map<String, String> headers) async {
    final email = (membro['email'] ?? '').toString().trim().toLowerCase();
    if (email.isEmpty) return _parseId(membro['id']);

    for (final c in contribuidores) {
      if ((c['email'] ?? '').toString().trim().toLowerCase() == email) {
        return _parseId(c['id']);
      }
    }
    final resp = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contribuidores}'),
      headers: headers,
      body: jsonEncode({
        "nome": membro['nome'],
        "email": membro['email'],
        "cargo": membro['papel'],
        "ativo": true,
      }),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      print('Não foi possível criar o contribuidor de $email: ${resp.body}');
      return null;
    }
    final criado = jsonDecode(resp.body);
    contribuidores.add(criado);
    return _parseId(criado['id']);
  }

  /// Vínculos pessoa-projeto (com o nome da pessoa), para o filtro de membros.
  static Future<List<dynamic>> getContribuidoresProjetos() async =>
      _get(ApiConfig.contribuidoresProjeto);
  static Future<List<dynamic>> getRecursos() async => _get(ApiConfig.recursos);

  // Novo método para buscar os IDs das tecnologias do projeto
  static Future<List<int>> getTecnologiasDoProjeto(int projetoId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/tecnologias-projeto/projeto/$projetoId');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Retorna apenas uma lista de IDs (ex: [1, 5, 9])
        // O Postgres devolve bigint como texto ("2"): converte com segurança.
        return data
            .map((item) => int.tryParse('${item['tecnologia_id']}'))
            .whereType<int>()
            .toList();
      }
      return [];
    } catch (e) {
      print("Erro ao buscar tecnologias do projeto: $e");
      return [];
    }
  }

  /// Deixa as tecnologias do projeto iguais a [desejadas]: adiciona as que
  /// faltam e remove as que saíram (o PUT de projetos não mexe nelas).
  static Future<void> sincronizarTecnologiasDoProjeto(
      int projetoId, Set<int> desejadas,
      {required int aprovadoPorId}) async {
    final atuais = (await getTecnologiasDoProjeto(projetoId)).toSet();
    final headers = await _getHeaders();
    final base = '${ApiConfig.baseUrl}${ApiConfig.tecnologiasProjeto}';

    for (final id in desejadas.difference(atuais)) {
      final resposta = await http.post(
        Uri.parse(base),
        headers: headers,
        body: jsonEncode({
          'projeto_id': projetoId,
          'tecnologia_id': id,
          'aprovado_por_id': aprovadoPorId,
          'data_aprovacao': DateTime.now().toIso8601String(),
        }),
      );
      if (resposta.statusCode >= 300) {
        throw Exception(
            'Erro ao adicionar tecnologia (${resposta.statusCode}): ${resposta.body}');
      }
    }

    for (final id in atuais.difference(desejadas)) {
      final resposta = await http.delete(Uri.parse('$base/$projetoId/$id'),
          headers: headers);
      // 404 = já não estava no projeto.
      if (resposta.statusCode >= 300 && resposta.statusCode != 404) {
        throw Exception(
            'Erro ao remover tecnologia (${resposta.statusCode}): ${resposta.body}');
      }
    }
  }
}
