import 'dart:convert';
import 'dart:typed_data';

import 'package:fabrica_software_app/config/projeto_dto.dart';
import 'package:fabrica_software_app/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'perguntas.dart';

/// Estados do botão de IA da barra.
enum EstadoIA { desabilitado, disponivel, ativo, gerando }

enum TipoExtra {
  /// Pedido do usuário para a IA (balão do usuário com ícone de IA).
  pedidoIA,

  /// Sugestão da IA, com Usar / Editar / Gerar de novo.
  sugestao,

  /// Comando sobre o diagrama.
  pedidoAjuste,

  /// Balão curto do sistema (resumo de uma geração ou comando).
  sistema,

  /// Resumo de um comando de IA sobre os requisitos (com Desfazer).
  resumoRequisitos,

  /// Bloco de cards de requisitos (sempre a versão atual da lista).
  blocoRequisitos,

  /// Card do diagrama de casos de uso (sempre a versão atual).
  cardDiagrama,

  /// Balão de carregamento.
  carregando,

  /// Erro mostrado como balão do sistema.
  erro,
}

/// Balão extra ligado a uma pergunta (IA, requisitos, diagrama, erro...).
class MensagemExtra {
  MensagemExtra(this.tipo, {this.texto = '', this.valor, this.pedido});

  final TipoExtra tipo;
  final String texto;

  /// Valor que a sugestão grava ao clicar em Usar (ou a lista anterior,
  /// no resumo de requisitos, para o Desfazer).
  final Object? valor;

  /// Pedido que gerou a sugestão (para "Gerar de novo").
  final String? pedido;

  bool usada = false;
}

/// Documentos que aparecem em "Documentos gerados".
enum DocumentoConversa { requisitos, casoUso }

/// Marca temporária de um card depois de um comando de IA.
enum MarcaRequisito { novo, alterado }

/// Uma versão do diagrama de casos de uso.
class Diagrama {
  Diagrama({
    required this.versao,
    this.titulo,
    this.mermaid,
    this.imagem,
    this.atores = const [],
    this.aviso,
  });

  final int versao;
  final String? titulo;
  final String? mermaid;
  final Uint8List? imagem;
  final List<String> atores;
  final String? aviso;

  /// Casos de uso do Mermaid (nós em forma de estádio: `UC1(["..."])`).
  int get casosDeUso => RegExp(r'\b(\w+)\(\[')
      .allMatches(mermaid ?? '')
      .map((m) => m.group(1))
      .toSet()
      .length;
}

/// Chave local que identifica cada requisito na tela (cards, marcas,
/// edição). Não é usada pelo envio.
const chaveIdRequisito = 'id_local';

/// Id do card de requisito novo (ainda não salvo), criado direto no bloco.
const idNovoRequisito = '__novo__';

/// Guarda a pergunta atual e as respostas, gravando cada resposta válida
/// em [projetoDraft] — o mesmo formulário que o wizard clássico preenche.
class ControladorConversa extends ChangeNotifier {
  ControladorConversa({List<Pergunta>? perguntas})
      : perguntas = perguntas ?? perguntasCriacao;

  final List<Pergunta> perguntas;
  ProjetoDTO get dados => projetoDraft;

  int _indiceAtual = 0;
  int? _editando;
  final Set<int> _respondidas = {};
  final Set<int> _puladas = {};
  final Map<int, List<MensagemExtra>> _extras = {};

  bool _iaAtiva = false;
  bool _gerando = false;
  bool _enviando = false;
  String? _erroEnvio;

  /// Muda sempre que entra um balão novo ou a pergunta avança
  /// (o modal rola o chat até o fim só nesses casos).
  int _versaoChat = 0;

  // Opções vindas dos endpoints existentes.
  final Map<FonteOpcoes, List<Map<String, dynamic>>> _opcoes = {
    FonteOpcoes.tipos: [
      for (final o in opcoesTipo) {'id': o, 'nome': o}
    ],
    FonteOpcoes.modelos: [
      for (final o in opcoesModelo) {'id': o, 'nome': o}
    ],
  };
  bool carregandoOpcoes = true;

  // Requisitos.
  int _versaoRequisitos = 0;
  int _proximoId = 0;
  String? _sessaoRequisitos;
  final Map<String, MarcaRequisito> _marcas = {};
  List<Map<String, dynamic>> _removidos = [];
  MensagemExtra? _resumoDesfazivel;
  String? _editandoRequisito;
  String? _destaqueRequisito;
  String? _rolarPara;

  // Diagrama de casos de uso.
  String? _sessaoDiagrama;
  Diagrama? _diagrama;
  Diagrama? _diagramaAnterior;
  String? _assinaturaDiagrama;

  DocumentoConversa? _documento;
  bool _descartado = false;

  /// O escopo foi enviado com a IA: o bloco só entra depois da geração
  /// (carregando → resumo → bloco).
  bool _geracaoPendente = false;

  // ---------------------------------------------------------------------
  // Leitura
  // ---------------------------------------------------------------------

  int get indiceAtual => _indiceAtual;
  int? get editando => _editando;
  int get versaoChat => _versaoChat;

  /// Pergunta que a barra está respondendo: a do documento aberto, a que
  /// está em edição ou a atual.
  int get indiceAtivo {
    final doc = _documento;
    if (doc != null) return indiceDoDocumento(doc);
    return _editando ?? _indiceAtual;
  }

  bool get concluido =>
      _indiceAtual >= perguntas.length &&
      _editando == null &&
      _documento == null;

  Pergunta? get perguntaAtiva =>
      indiceAtivo < perguntas.length ? perguntas[indiceAtivo] : null;

  bool respondida(int i) => _respondidas.contains(i);
  bool pulada(int i) => _puladas.contains(i);
  bool get temResposta => _respondidas.isNotEmpty;

  List<MensagemExtra> extras(int i) => _extras[i] ?? const [];

  bool get enviando => _enviando;
  String? get erroEnvio => _erroEnvio;
  bool get gerando => _gerando;

  EstadoIA get estadoIA {
    final p = perguntaAtiva;
    if (p == null || !p.ia) return EstadoIA.desabilitado;
    if (_gerando) return EstadoIA.gerando;
    if (p.iaFixa) return EstadoIA.ativo;
    return _iaAtiva ? EstadoIA.ativo : EstadoIA.disponivel;
  }

  double get progresso =>
      perguntas.isEmpty ? 1 : _respondidas.length / perguntas.length;

  Etapa get etapaAtual {
    if (_indiceAtual >= perguntas.length) return Etapa.values.last;
    return perguntas[_editando ?? _indiceAtual].etapa;
  }

  /// A etapa já apareceu no chat (pode ser aberta pela sidebar).
  bool etapaAlcancada(Etapa etapa) =>
      concluido || etapaAtual.index >= etapa.index;

  bool etapaConcluida(Etapa etapa) {
    final indices = [
      for (var i = 0; i < perguntas.length; i++)
        if (perguntas[i].etapa == etapa) i
    ];
    return indices.isNotEmpty &&
        indices.every(_respondidas.contains) &&
        (concluido || etapaAtual.index > etapa.index);
  }

  List<Map<String, dynamic>> opcoes(FonteOpcoes? fonte) =>
      fonte == null ? const [] : _opcoes[fonte] ?? const [];

  int indiceDoCampo(String campo) =>
      perguntas.indexWhere((p) => p.campo == campo);

  int indiceDoDocumento(DocumentoConversa doc) => indiceDoCampo(
      doc == DocumentoConversa.requisitos ? 'requisitos' : 'diagrama');

  // ---------------------------------------------------------------------
  // Carregamento
  // ---------------------------------------------------------------------

  Future<void> carregarOpcoes() async {
    Future<void> carregar(
        FonteOpcoes fonte, Future<List<dynamic>> Function() buscar) async {
      try {
        final lista = await buscar();
        _opcoes[fonte] = [
          for (final item in lista)
            if (item is Map) Map<String, dynamic>.from(item)
        ];
      } catch (e) {
        debugPrint('Falha ao carregar ${fonte.name}: $e');
        _opcoes[fonte] = [];
      }
    }

    await Future.wait([
      carregar(FonteOpcoes.clientes, ApiService.getClientes),
      carregar(FonteOpcoes.tecnologias, ApiService.getTecnologias),
      carregar(FonteOpcoes.contribuidores, ApiService.getContribuidores),
      carregar(FonteOpcoes.recursos, ApiService.getRecursos),
    ]);
    carregandoOpcoes = false;
    _notificar();
  }

  // ---------------------------------------------------------------------
  // Valores do formulário
  // ---------------------------------------------------------------------

  /// Valor atual de um campo, no formato que a barra usa.
  Object? valor(String campo) {
    final d = dados;
    switch (campo) {
      case 'nome':
        return d.nome;
      case 'tipo':
        return d.tipo;
      case 'modelo':
        return d.modelo;
      case 'cliente':
        return d.cliente;
      case 'metodologia':
        return d.metodologia;
      case 'tecnologias':
        return d.tecnologias;
      case 'descricao':
        return d.descricao;
      case 'escopo':
        return d.escopo;
      case 'requisitos':
        return d.requisitos;
      case 'equipe':
        return d.equipe;
      case 'recursos':
        return d.recursos;
      case 'dataInicio':
        return d.dataInicio;
      case 'dataFinalPrevista':
        return d.dataFinalPrevista;
      case 'orcamentoEstimado':
        return d.orcamentoEstimado;
    }
    return null;
  }

  void _gravar(String campo, Object? v) {
    final d = dados;
    String? texto() {
      final t = (v as String?)?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    List<Map<String, dynamic>> lista() => [
          for (final m in (v as List? ?? const [])) Map<String, dynamic>.from(m)
        ];

    switch (campo) {
      case 'nome':
        d.nome = texto();
      case 'tipo':
        d.tipo = texto();
      case 'modelo':
        d.modelo = texto();
      case 'cliente':
        d.cliente = v == null ? null : Map<String, dynamic>.from(v as Map);
      case 'metodologia':
        d.metodologia = texto();
      case 'tecnologias':
        d.tecnologias = lista();
      case 'descricao':
        d.descricao = texto();
      case 'escopo':
        d.escopo = texto();
      case 'requisitos':
        d.requisitos = lista();
      case 'equipe':
        // Mesmo formato do passo "Alocação de Recursos".
        d.equipe = [
          for (final c in lista())
            {
              'id': c['id'],
              'nome': c['nome'],
              'papel': c['papel'] ?? c['cargo'] ?? 'N/A',
            }
        ];
      case 'recursos':
        d.recursos = [
          for (final r in lista())
            {'id': r['id'], 'nome': r['nome'], 'tipo': r['tipo']}
        ];
      case 'dataInicio':
        d.dataInicio = v as DateTime?;
      case 'dataFinalPrevista':
        d.dataFinalPrevista = v as DateTime?;
      case 'orcamentoEstimado':
        d.orcamentoEstimado = v as double?;
    }
  }

  /// Texto do balão de resposta de uma pergunta.
  String textoResposta(int i) {
    if (_puladas.contains(i)) return 'Pular';
    final p = perguntas[i];
    final v = valor(p.campo);
    final datas = DateFormat('dd/MM/yyyy');
    switch (p.campo) {
      case 'cliente':
        return (v as Map?)?['razao_social']?.toString() ?? '';
      case 'tecnologias':
      case 'equipe':
      case 'recursos':
        return (v as List).map((m) => m['nome']).join(', ');
      case 'requisitos':
        return '${contagemRequisitos.total} requisitos aprovados '
            '(${contagemRequisitos.funcionais} funcionais e '
            '${contagemRequisitos.naoFuncionais} não funcionais)';
      case 'diagrama':
        final d = _diagrama;
        return d == null
            ? 'Seguir sem diagrama'
            : 'Diagrama aprovado (v${d.versao})';
      case 'dataInicio':
      case 'dataFinalPrevista':
        return v == null ? '' : datas.format(v as DateTime);
      case 'orcamentoEstimado':
        return v == null ? '' : formatarMoeda(v as double);
    }
    return v?.toString() ?? '';
  }

  /// Valor no formato da máscara da barra (100.000 / 1.234,5).
  static String formatarNumero(double v) =>
      NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: 2)
          .format(v)
          .replaceAll(RegExp(r',00$'), '');

  static String formatarMoeda(double v) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);

  // ---------------------------------------------------------------------
  // Respostas
  // ---------------------------------------------------------------------

  /// Valida e grava a resposta da pergunta ativa.
  /// Devolve a mensagem de erro, ou `null` se a resposta foi aceita.
  String? responder(Object? resposta) {
    final i = indiceAtivo;
    if (i >= perguntas.length || _documento != null) return null;
    final p = perguntas[i];

    final erro = _validar(p, resposta);
    if (erro != null) return erro;

    _gravar(p.campo, resposta);
    _puladas.remove(i);
    _concluirPergunta(i);
    return null;
  }

  /// Pula uma pergunta opcional (grava vazio, como o input vazio de hoje).
  void pular() {
    final i = indiceAtivo;
    final p = perguntaAtiva;
    if (p == null || p.obrigatorio || _documento != null) return;
    _gravar(p.campo, p.modo == ModoResposta.multipla ? const [] : null);
    _puladas.add(i);
    _concluirPergunta(i);
  }

  /// Segue para a próxima pergunta sem gravar valor (diagrama).
  void continuar() {
    if (_documento != null || _gerando) return;
    final i = indiceAtivo;
    _puladas.remove(i);
    _concluirPergunta(i);
  }

  void _concluirPergunta(int i) {
    _respondidas.add(i);
    _iaAtiva = false;
    if (_editando != null) {
      _editando = null;
    } else {
      _indiceAtual++;
      _aoEntrarNaPergunta();
    }
    _versaoChat++;
    _notificar();
  }

  String? _validar(Pergunta p, Object? v) {
    final vazio = v == null ||
        (v is String && v.trim().isEmpty) ||
        (v is List && v.isEmpty);
    if (vazio) {
      if (!p.obrigatorio) return null;
      return p.campo == 'requisitos'
          ? 'É necessário adicionar pelo menos um requisito para continuar.'
          : 'Essa resposta é obrigatória.';
    }

    switch (p.campo) {
      case 'nome':
        if ((v as String).trim().length > 255) {
          return 'O nome pode ter no máximo 255 caracteres.';
        }
      case 'dataInicio':
        final fim = dados.dataFinalPrevista;
        if (fim != null && (v as DateTime).isAfter(fim)) {
          return 'Data inicial inválida: ela é depois da data final.';
        }
      case 'dataFinalPrevista':
        final inicio = dados.dataInicio;
        if (inicio != null && (v as DateTime).isBefore(inicio)) {
          return 'Data final inválida: ela é antes da data de início.';
        }
      case 'orcamentoEstimado':
        if ((v as double) < 0) return 'Informe um valor válido.';
    }
    return null;
  }

  void editar(int i) {
    if (!_respondidas.contains(i) || _enviando) return;
    _documento = null;
    _editando = i;
    _iaAtiva = false;
    _editandoRequisito = null;
    _notificar();
  }

  void cancelarEdicao() {
    _editando = null;
    _iaAtiva = false;
    _notificar();
  }

  void _aoEntrarNaPergunta() {
    final p = perguntaAtiva;
    if (p == null) return;
    _iaAtiva = p.iaInicial;
    switch (p.modo) {
      case ModoResposta.requisitos:
        // Com requisitos gerados a barra abre em comandos de IA; sem eles,
        // direto no requisito manual.
        _iaAtiva = dados.requisitos.isNotEmpty || _geracaoPendente;
        if (!_geracaoPendente) {
          _garantirBloco(_indiceAtual, TipoExtra.blocoRequisitos);
        }
      case ModoResposta.diagrama:
        if (_diagrama == null) gerarDiagrama();
      default:
        break;
    }
  }

  // ---------------------------------------------------------------------
  // Documentos gerados
  // ---------------------------------------------------------------------

  DocumentoConversa? get documentoAberto => _documento;

  /// Documentos listados na sidebar, com a versão atual.
  List<({DocumentoConversa doc, String titulo, int versao})>
      get documentosGerados => [
            if (_versaoRequisitos > 0 || dados.requisitos.isNotEmpty)
              (
                doc: DocumentoConversa.requisitos,
                titulo: 'REQUISITOS',
                versao: _versaoRequisitos < 1 ? 1 : _versaoRequisitos,
              ),
            if (_diagrama != null)
              (
                doc: DocumentoConversa.casoUso,
                titulo: 'CASO DE USO',
                versao: _diagrama!.versao,
              ),
          ];

  void abrirDocumento(DocumentoConversa doc) {
    _documento = doc;
    _editando = null;
    _iaAtiva = doc == DocumentoConversa.requisitos
        ? dados.requisitos.isNotEmpty
        : true;
    _notificar();
  }

  void fecharDocumento() {
    _documento = null;
    final p = perguntaAtiva;
    _iaAtiva = p?.modo == ModoResposta.requisitos
        ? dados.requisitos.isNotEmpty
        : false;
    _notificar();
  }

  /// Último balão de resumo/carregamento/erro de um documento (mostrado no
  /// documento aberto, abaixo do bloco).
  MensagemExtra? ultimoAvisoDo(DocumentoConversa doc) {
    final lista = extras(indiceDoDocumento(doc));
    for (final m in lista.reversed) {
      switch (m.tipo) {
        case TipoExtra.sistema:
        case TipoExtra.resumoRequisitos:
        case TipoExtra.carregando:
        case TipoExtra.erro:
          return m;
        case TipoExtra.pedidoIA:
        case TipoExtra.pedidoAjuste:
          continue;
        default:
          return null;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // IA (botão da barra)
  // ---------------------------------------------------------------------

  void alternarIA() {
    final estado = estadoIA;
    final p = perguntaAtiva;
    if (estado == EstadoIA.desabilitado ||
        estado == EstadoIA.gerando ||
        p == null ||
        p.iaFixa) {
      return;
    }
    _iaAtiva = !_iaAtiva;
    _notificar();
  }

  /// Envia o texto da barra para a IA, conforme a pergunta:
  /// escopo gera os requisitos, requisitos e diagrama recebem comandos, e
  /// as demais perguntas recebem uma sugestão (só entra com "Usar").
  Future<void> pedirIA(String pedido) async {
    final p = perguntaAtiva;
    if (p == null || !p.ia || _gerando) return;

    switch (p.modo) {
      case ModoResposta.requisitos:
        return comandoRequisitos(pedido);
      case ModoResposta.diagrama:
        return ajustarDiagrama(pedido);
      default:
        if (p.campo == 'escopo') return _enviarEscopo(pedido);
    }

    final i = indiceAtivo;
    final baloes = _extras.putIfAbsent(i, () => []);
    if (pedido.trim().isNotEmpty) {
      _adicionar(i, MensagemExtra(TipoExtra.pedidoIA, texto: pedido.trim()));
    }
    final carregando = MensagemExtra(TipoExtra.carregando);
    _adicionar(i, carregando);
    _gerando = true;
    _notificar();

    try {
      final sugestao = await _gerarSugestao(p, pedido.trim());
      _adicionar(i, sugestao);
    } catch (e) {
      _adicionar(
          i,
          MensagemExtra(TipoExtra.erro,
              texto: 'Não consegui gerar a sugestão agora. ($e)'));
    } finally {
      baloes.remove(carregando);
      _gerando = false;
      _notificar();
    }
  }

  Future<MensagemExtra> _gerarSugestao(Pergunta p, String pedido) async {
    final d = dados;
    final nome = d.nome ?? 'Novo Projeto';

    switch (p.campo) {
      case 'orcamentoEstimado':
        final inicio = d.dataInicio, fim = d.dataFinalPrevista;
        if (inicio == null || fim == null) {
          throw Exception('defina as datas antes de estimar');
        }
        final r = await ApiService.estimarOrcamentoBackend({
          'nome': d.nome,
          'descricao': d.descricao,
          'escopo': d.escopo ?? '',
          'duracao_dias': fim.difference(inicio).inDays,
          'equipe': d.equipe,
          'recursos': d.recursos,
        });
        final valor =
            double.tryParse(r['orcamento_estimado'].toString()) ?? 0.0;
        d.complexidade = r['complexidade']?.toString() ?? 'media';
        return MensagemExtra(TipoExtra.sugestao,
            texto: '${formatarMoeda(valor)} · complexidade ${d.complexidade}',
            valor: valor,
            pedido: pedido);

      default: // metodologia, descricao: texto do chat de requisitos
        final instrucao = switch (p.campo) {
          'metodologia' => 'Responda apenas com o nome da metodologia de '
              'desenvolvimento mais indicada para o projeto "$nome".',
          _ => 'Escreva o objetivo do projeto "$nome" em um único '
              'parágrafo curto, sem listas e sem comentários extras.',
        };
        final r = await ApiService.chatRequisitos(
          mensagem: '$instrucao${pedido.isEmpty ? '' : ' Pedido: $pedido'}',
          nomeProjeto: nome,
          escopo: d.escopo ?? d.descricao,
          requisitosAtuais: const [],
        );
        final texto = (r['resposta_chat'] ?? '').toString().trim();
        if (texto.isEmpty) throw Exception('a IA não devolveu texto');
        return MensagemExtra(TipoExtra.sugestao,
            texto: texto, valor: texto, pedido: pedido);
    }
  }

  /// "Usar": grava a sugestão como resposta da pergunta.
  void usarSugestao(MensagemExtra m) {
    if (perguntaAtiva == null || m.usada) return;
    m.usada = true;
    _iaAtiva = false;
    responder(m.valor);
  }

  Future<void> gerarDeNovo(MensagemExtra m) => pedirIA(m.pedido ?? '');

  String? _textoParaBarra;

  /// "Editar": leva a sugestão para a barra, para o usuário ajustar antes
  /// de enviar como resposta normal.
  void editarSugestao(MensagemExtra m) {
    if (perguntaAtiva == null || m.usada) return;
    m.usada = true;
    _iaAtiva = false;
    final v = m.valor;
    _textoParaBarra = v is double ? formatarNumero(v) : v?.toString();
    _notificar();
  }

  /// Texto que a barra deve exibir (lido uma única vez).
  String? consumirTextoParaBarra() {
    final t = _textoParaBarra;
    _textoParaBarra = null;
    return t;
  }

  // ---------------------------------------------------------------------
  // Requisitos: geração
  // ---------------------------------------------------------------------

  int get versaoRequisitos => _versaoRequisitos;

  /// Escopo enviado com a IA ativa: vira a resposta da pergunta e dispara a
  /// geração (a mesma chamada do botão "Gerar Requisitos com IA").
  Future<void> _enviarEscopo(String escopo) async {
    final i = indiceAtivo;
    _gravar('escopo', escopo);
    _puladas.remove(i);
    _geracaoPendente = true;
    _concluirPergunta(i);
    _geracaoPendente = false;
    await gerarRequisitos();
  }

  /// Gera a lista inteira a partir do escopo (inicial ou "Gerar novamente").
  Future<void> gerarRequisitos() async {
    final i = indiceDoCampo('requisitos');
    final escopo = (dados.escopo ?? '').trim();
    if (i < 0 || _gerando) return;
    if (escopo.isEmpty) {
      _adicionar(
          i,
          MensagemExtra(TipoExtra.erro,
              texto: 'Por favor, descreva o escopo do projeto antes de '
                  'chamar a IA.'));
      _notificar();
      return;
    }

    _iniciarAcaoRequisitos();
    final carregando =
        MensagemExtra(TipoExtra.carregando, texto: 'Gerando requisitos...');
    _adicionar(i, carregando);
    _gerando = true;
    _iaAtiva = true;
    _notificar();

    try {
      final lista = await ApiService.gerarRequisitosBackend(
          escopo, dados.nome ?? 'Novo Projeto');
      if (_descartado) return;
      dados.requisitos = [
        for (final r in lista)
          _novoRequisito(Map<String, dynamic>.from(r), ia: true)
      ];
      _versaoRequisitos++;
      _sessaoRequisitos = null;
      final c = contagemRequisitos;
      _adicionar(
          i,
          MensagemExtra(TipoExtra.sistema,
              texto: 'Gerei ${c.total} requisitos: ${c.funcionais} '
                  'funcionais e ${c.naoFuncionais} não funcionais.'));
      _garantirBloco(i, TipoExtra.blocoRequisitos);
    } catch (e) {
      _adicionar(
          i,
          MensagemExtra(TipoExtra.erro,
              texto: 'Erro ao conectar com a IA: $e'));
      _garantirBloco(i, TipoExtra.blocoRequisitos);
      _iaAtiva = dados.requisitos.isNotEmpty;
    } finally {
      _extras[i]?.remove(carregando);
      _gerando = false;
      _notificar();
    }
  }

  Map<String, dynamic> _novoRequisito(Map<String, dynamic> r,
      {required bool ia}) {
    return {
      ...r,
      chaveIdRequisito: 'r${_proximoId++}',
      'titulo': (r['titulo'] ?? 'Requisito Sugerido').toString(),
      'descricao': (r['descricao'] ?? '').toString(),
      'tipo': (r['tipo'] ?? 'Funcional').toString(),
      'prioridade': (r['prioridade'] ?? 'Média').toString(),
      'is_ai_generated': ia,
      // Como na tela antiga: o que a IA cria entra pendente; o manual,
      // já aprovado.
      'is_approved': !ia,
      'is_edited': false,
    };
  }

  // ---------------------------------------------------------------------
  // Requisitos: comandos de IA
  // ---------------------------------------------------------------------

  /// Comando em texto livre para o assistente de requisitos (mesma chamada
  /// do chat lateral da tela antiga). Aplicado direto, sem confirmação.
  Future<void> comandoRequisitos(String mensagem) async {
    final i = indiceDoCampo('requisitos');
    final texto = mensagem.trim();
    if (i < 0 || texto.isEmpty || _gerando) return;

    _iniciarAcaoRequisitos();
    _adicionar(i, MensagemExtra(TipoExtra.pedidoIA, texto: texto));
    final carregando =
        MensagemExtra(TipoExtra.carregando, texto: 'Atualizando requisitos...');
    _adicionar(i, carregando);
    _gerando = true;
    _notificar();

    final antes = [
      for (final r in dados.requisitos) Map<String, dynamic>.from(r)
    ];
    try {
      final r = await ApiService.chatRequisitos(
        sessionId: _sessaoRequisitos,
        mensagem: texto,
        nomeProjeto: dados.nome ?? 'Novo Projeto',
        escopo: dados.escopo,
        requisitosAtuais: [
          for (final req in dados.requisitos)
            {
              'titulo': req['titulo'],
              'descricao': req['descricao'],
              'tipo': req['tipo'],
              'prioridade': req['prioridade'],
            }
        ],
      );
      if (_descartado) return;
      _sessaoRequisitos = r['sessionId']?.toString() ?? _sessaoRequisitos;

      final novaLista = r['requisitos'];
      var resumo = '';
      if (novaLista is List) {
        final (:adicionados, :alterados, :removidos) =
            _reconciliar(novaLista.cast<Map>());
        final partes = [
          if (adicionados > 0) 'adicionei $adicionados',
          if (alterados > 0) 'alterei $alterados',
          if (removidos > 0) 'removi $removidos',
        ];
        if (partes.isNotEmpty) {
          resumo = '${partes.join(', ')}.';
          resumo = resumo[0].toUpperCase() + resumo.substring(1);
        }
      }
      final respostaIA = (r['resposta_chat'] ?? '').toString().trim();
      final textoResumo = [
        if (resumo.isNotEmpty) resumo,
        if (respostaIA.isNotEmpty) respostaIA,
      ].join('\n');

      final balao = MensagemExtra(
        TipoExtra.resumoRequisitos,
        texto: textoResumo.isEmpty ? 'Nenhuma mudança na lista.' : textoResumo,
        valor: antes,
      );
      _adicionar(i, balao);
      if (resumo.isNotEmpty) _resumoDesfazivel = balao;
    } catch (e) {
      _adicionar(
          i,
          MensagemExtra(TipoExtra.erro,
              texto: 'Erro ao conversar com a IA: $e'));
    } finally {
      _extras[i]?.remove(carregando);
      _gerando = false;
      _notificar();
    }
  }

  /// Aplica a lista devolvida pela IA, como a tela antiga fazia: itens
  /// idênticos (título + descrição) continuam como estão; itens novos
  /// entram pendentes e os que sumiram da resposta são removidos.
  /// A diferença: mesmo título com outro conteúdo conta como "Alterado".
  ({int adicionados, int alterados, int removidos}) _reconciliar(
      List<Map> resposta) {
    String chave(Map r) => '${r['titulo']}'.trim().toLowerCase();
    final atuais = [...dados.requisitos];
    final usados = <String>{};
    final resultado = <Map<String, dynamic>>[];
    var adicionados = 0, alterados = 0;

    for (final bruto in resposta) {
      final r = Map<String, dynamic>.from(bruto);
      final identico = atuais.where((a) =>
          !usados.contains(a[chaveIdRequisito]) &&
          a['titulo'] == r['titulo'] &&
          a['descricao'] == r['descricao']);
      if (identico.isNotEmpty) {
        final a = identico.first;
        usados.add(a[chaveIdRequisito]);
        resultado.add(a);
        continue;
      }

      final mesmoTitulo = atuais.where(
          (a) => !usados.contains(a[chaveIdRequisito]) && chave(a) == chave(r));
      if (mesmoTitulo.isNotEmpty) {
        final a = mesmoTitulo.first;
        usados.add(a[chaveIdRequisito]);
        resultado.add({
          ...a,
          'titulo': r['titulo'] ?? a['titulo'],
          'descricao': r['descricao'] ?? a['descricao'],
          'tipo': r['tipo'] ?? a['tipo'],
          'prioridade': r['prioridade'] ?? a['prioridade'],
          'is_ai_generated': true,
          'is_approved': false,
          'is_edited': true,
        });
        _marcas[a[chaveIdRequisito]] = MarcaRequisito.alterado;
        alterados++;
        continue;
      }

      final novo = _novoRequisito(r, ia: true);
      resultado.add(novo);
      _marcas[novo[chaveIdRequisito]] = MarcaRequisito.novo;
      adicionados++;
    }

    _removidos = [
      for (final a in atuais)
        if (!usados.contains(a[chaveIdRequisito])) a
    ];
    dados.requisitos = resultado;
    return (
      adicionados: adicionados,
      alterados: alterados,
      removidos: _removidos.length,
    );
  }

  MarcaRequisito? marcaDe(String id) => _marcas[id];
  List<Map<String, dynamic>> get requisitosRemovidos => _removidos;
  bool podeDesfazer(MensagemExtra m) => identical(_resumoDesfazivel, m);

  /// Desfaz o último comando da IA (volta a lista de antes do comando).
  void desfazer(MensagemExtra m) {
    if (!podeDesfazer(m)) return;
    dados.requisitos = [
      for (final r in (m.valor as List)) Map<String, dynamic>.from(r)
    ];
    m.usada = true;
    _iniciarAcaoRequisitos();
    _notificar();
  }

  /// "Próxima ação": as marcas Novo/Alterado/Removido e o Desfazer valem
  /// só até o usuário fazer outra coisa na lista.
  void _iniciarAcaoRequisitos() {
    _marcas.clear();
    _removidos = [];
    _resumoDesfazivel = null;
    _destaqueRequisito = null;
  }

  // ---------------------------------------------------------------------
  // Requisitos: cards e requisito manual
  // ---------------------------------------------------------------------

  ({int total, int funcionais, int naoFuncionais, int aprovados})
      get contagemRequisitos {
    final lista = dados.requisitos;
    final funcionais = lista.where(ehFuncional).length;
    return (
      total: lista.length,
      funcionais: funcionais,
      naoFuncionais: lista.length - funcionais,
      aprovados: lista.where((r) => r['is_approved'] == true).length,
    );
  }

  static bool ehFuncional(Map r) =>
      (r['tipo'] ?? 'Funcional').toString().toLowerCase() == 'funcional';

  int get requisitosPendentes =>
      contagemRequisitos.total - contagemRequisitos.aprovados;

  String? get editandoRequisito => _editandoRequisito;
  String? get destaqueRequisito => _destaqueRequisito;

  Map<String, dynamic>? requisitoPorId(String id) {
    for (final r in dados.requisitos) {
      if (r[chaveIdRequisito] == id) return r;
    }
    return null;
  }

  void _atualizarRequisito(
      String id, Map<String, dynamic> Function(Map<String, dynamic>) mudar) {
    dados.requisitos = [
      for (final r in dados.requisitos) r[chaveIdRequisito] == id ? mudar(r) : r
    ];
  }

  void alternarAprovacao(String id) {
    _iniciarAcaoRequisitos();
    _atualizarRequisito(
        id, (r) => {...r, 'is_approved': !(r['is_approved'] == true)});
    _notificar();
  }

  void aprovarTodos() {
    _iniciarAcaoRequisitos();
    dados.requisitos = [
      for (final r in dados.requisitos) {...r, 'is_approved': true}
    ];
    _notificar();
  }

  void excluirRequisito(String id) {
    _iniciarAcaoRequisitos();
    dados.requisitos = [
      for (final r in dados.requisitos)
        if (r[chaveIdRequisito] != id) r
    ];
    if (_editandoRequisito == id) _editandoRequisito = null;
    _notificar();
  }

  String _tituloRascunho = '';

  /// Título já digitado na barra para o card novo.
  String get tituloRascunho => _tituloRascunho;

  /// Cria um card novo, já aberto para edição, no fim do bloco.
  void novoRequisito([String titulo = '']) {
    _iniciarAcaoRequisitos();
    _tituloRascunho = titulo.trim();
    _editandoRequisito = idNovoRequisito;
    _rolarPara = idNovoRequisito;
    final i = indiceDoCampo('requisitos');
    if (i >= 0) _garantirBloco(i, TipoExtra.blocoRequisitos);
    _notificar();
  }

  /// "Adicionar manualmente" do rodapé do bloco.
  void abrirRequisitoManual() => novoRequisito();

  /// Lápis do card: o próprio card vira o formulário de edição.
  void editarRequisito(String id) {
    if (requisitoPorId(id) == null) return;
    _iniciarAcaoRequisitos();
    _editandoRequisito = id;
    _notificar();
  }

  void cancelarEdicaoRequisito() {
    _editandoRequisito = null;
    _notificar();
  }

  /// "Adicionar" (ou "Salvar", ao editar um card) do requisito manual.
  String? salvarRequisitoManual({
    required String titulo,
    required String descricao,
    required String tipo,
    required String prioridade,
  }) {
    final t = titulo.trim(), d = descricao.trim();
    if (t.isEmpty || d.isEmpty) {
      return 'Preencha o título e a descrição do requisito.';
    }
    _iniciarAcaoRequisitos();
    final id = _editandoRequisito;
    if (id != null && id != idNovoRequisito) {
      _atualizarRequisito(
        id,
        (r) => {
          ...r,
          'titulo': t,
          'descricao': d,
          'tipo': tipo,
          'prioridade': prioridade,
          'is_edited': true,
        },
      );
      _editandoRequisito = null;
    } else {
      _editandoRequisito = null;
      _tituloRascunho = '';
      dados.requisitos = [
        ...dados.requisitos,
        _novoRequisito({
          'titulo': t,
          'descricao': d,
          'tipo': tipo,
          'prioridade': prioridade
        }, ia: false),
      ];
    }
    final i = indiceDoCampo('requisitos');
    if (i >= 0) _garantirBloco(i, TipoExtra.blocoRequisitos);
    _notificar();
    return null;
  }

  /// "Próxima etapa" nos requisitos. Os pendentes são aprovados ao avançar,
  /// como já acontecia na tela antiga.
  String? avancarRequisitos() {
    if (dados.requisitos.isEmpty) {
      return 'É necessário adicionar pelo menos um requisito para continuar.';
    }
    aprovarTodos();
    _editandoRequisito = null;
    return responder(dados.requisitos);
  }

  /// "Voltar e revisar": destaca e rola até o primeiro card pendente.
  void revisarPendentes() {
    for (final r in dados.requisitos) {
      if (r['is_approved'] != true) {
        _destaqueRequisito = r[chaveIdRequisito];
        _rolarPara = _destaqueRequisito;
        break;
      }
    }
    _notificar();
  }

  /// Card até onde o modal deve rolar (lido uma única vez).
  String? consumirRolagem() {
    final id = _rolarPara;
    _rolarPara = null;
    return id;
  }

  // ---------------------------------------------------------------------
  // Diagrama de casos de uso
  // ---------------------------------------------------------------------

  Diagrama? get diagrama => _diagrama;
  Diagrama? get diagramaAnterior => _diagramaAnterior;

  String _assinaturaRequisitos() => [
        for (final r in dados.requisitos)
          '${r['titulo']}|${r['descricao']}|${r['tipo']}|${r['prioridade']}'
      ].join('\n');

  /// Os requisitos mudaram depois da última geração do diagrama.
  bool get requisitosMudaram =>
      _diagrama != null && _assinaturaDiagrama != _assinaturaRequisitos();

  /// Gera o diagrama inteiro (ao entrar na etapa ou "Gerar novamente").
  /// Mesma chamada e mesmos dados da tela antiga.
  Future<void> gerarDiagrama() async {
    final i = indiceDoCampo('diagrama');
    if (i < 0 || _gerando) return;
    final assinatura = _assinaturaRequisitos();
    await _chamarDiagrama(
      i,
      () => ApiService.gerarDiagramaCasoUso(
        dados.nome ?? 'Novo Projeto',
        dados.escopo,
        [
          for (final r in dados.requisitos)
            {
              'titulo': r['titulo'],
              'descricao': r['descricao'],
              'tipo': r['tipo'],
              'prioridade': r['prioridade'],
            }
        ],
      ),
      novaVersao: true,
      aoConcluir: (d, r) {
        _assinaturaDiagrama = assinatura;
        return 'Gerei o diagrama com ${d.casosDeUso} casos de uso e '
            '${d.atores.length} atores.';
      },
    );
  }

  /// Comando sobre o diagrama (mesma chamada do chat lateral do Caso de uso).
  Future<void> ajustarDiagrama(String instrucao) async {
    final i = indiceDoCampo('diagrama');
    final texto = instrucao.trim();
    if (i < 0 || texto.isEmpty || _gerando) return;
    _adicionar(i, MensagemExtra(TipoExtra.pedidoAjuste, texto: texto));

    final sessao = _sessaoDiagrama;
    if (sessao == null || _diagrama == null) {
      _adicionar(
          i,
          MensagemExtra(TipoExtra.erro,
              texto: 'Ainda não há um diagrama para ajustar. Clique em '
                  '"Gerar novamente" para criar um.'));
      _notificar();
      return;
    }
    await _chamarDiagrama(
      i,
      () => ApiService.refinarDiagramaCasoUso(sessao, texto),
      novaVersao: false,
      aoConcluir: (d, r) {
        final resposta = (r['resposta_chat'] ?? '').toString().trim();
        return resposta.isEmpty ? 'Diagrama atualizado.' : resposta;
      },
    );
  }

  Future<void> _chamarDiagrama(
    int i,
    Future<Map<String, dynamic>> Function() chamada, {
    required bool novaVersao,
    required String Function(Diagrama, Map<String, dynamic>) aoConcluir,
  }) async {
    final carregando = MensagemExtra(TipoExtra.carregando,
        texto: novaVersao ? 'Gerando diagrama...' : 'Atualizando diagrama...');
    _adicionar(i, carregando);
    _gerando = true;
    _notificar();

    try {
      final r = await chamada();
      if (_descartado) return;
      _sessaoDiagrama = r['sessionId']?.toString() ?? _sessaoDiagrama;
      final base64 = r['imagem_base64']?.toString();
      final imagem =
          (base64 == null || base64.isEmpty) ? null : base64Decode(base64);

      final atual = _diagrama;
      final novo = Diagrama(
        versao: novaVersao ? (atual?.versao ?? 0) + 1 : (atual?.versao ?? 1),
        titulo: r['titulo']?.toString() ?? atual?.titulo,
        mermaid: r['mermaid']?.toString(),
        imagem: imagem,
        atores: [for (final a in (r['atores'] as List? ?? const [])) '$a'],
        aviso: r['aviso_renderizacao']?.toString(),
      );
      _diagramaAnterior = atual;
      _aplicarDiagrama(novo);

      _adicionar(
          i, MensagemExtra(TipoExtra.sistema, texto: aoConcluir(novo, r)));
      _garantirBloco(i, TipoExtra.cardDiagrama);
    } catch (e) {
      _adicionar(
          i,
          MensagemExtra(TipoExtra.erro,
              texto: 'Não foi possível gerar o diagrama: $e'));
    } finally {
      _extras[i]?.remove(carregando);
      _gerando = false;
      _notificar();
    }
  }

  /// Mesmos campos que o passo "Diagrama de Casos de Uso" grava.
  void _aplicarDiagrama(Diagrama d) {
    _diagrama = d;
    dados.diagramaCasoUsoTitulo = d.titulo;
    dados.diagramaCasoUsoMermaid = d.mermaid;
    dados.diagramaCasoUsoImagemBase64 =
        d.imagem == null ? null : base64Encode(d.imagem!);
    dados.diagramaCasoUsoAtores = d.atores;
  }

  /// "Restaurar": volta para a versão anterior do diagrama.
  void restaurarDiagramaAnterior() {
    final anterior = _diagramaAnterior;
    if (anterior == null || _gerando) return;
    _diagramaAnterior = _diagrama;
    _aplicarDiagrama(anterior);
    _notificar();
  }

  // ---------------------------------------------------------------------
  // Balões
  // ---------------------------------------------------------------------

  void _adicionar(int i, MensagemExtra m) {
    _extras.putIfAbsent(i, () => []).add(m);
    _versaoChat++;
  }

  /// O bloco de requisitos e o card do diagrama aparecem uma única vez no
  /// chat e mostram sempre a versão atual.
  void _garantirBloco(int i, TipoExtra tipo) {
    final existe = extras(i).any((m) => m.tipo == tipo);
    if (!existe) _adicionar(i, MensagemExtra(tipo));
  }

  // ---------------------------------------------------------------------
  // Rascunho e envio
  // ---------------------------------------------------------------------

  /// Ainda sem regra definida: quando houver, só esta função muda.
  void salvarRascunho(ProjetoDTO formData) {}

  /// "Criar projeto": mesma requisição do botão "Criar projeto" do wizard.
  Future<bool> criarProjeto(int? usuarioLogadoId) async {
    if (_enviando) return false;
    _enviando = true;
    _erroEnvio = null;
    _notificar();

    try {
      if (usuarioLogadoId == null) {
        throw Exception('Sessão inválida. Faça login novamente.');
      }
      dados.complexidade ??= 'media';
      await ApiService.criarProjetoCompleto(
          dados.montarPayloadCriacao(usuarioLogadoId));
      return true;
    } catch (e) {
      _erroEnvio = 'Erro ao salvar: $e';
      _versaoChat++;
      return false;
    } finally {
      _enviando = false;
      _notificar();
    }
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
