import 'package:fabrica_software_app/models/projeto.dart';

class ProjetoDTO {
  int? id; 
  String? nome;
  String? descricao;
  String? modelo;
  String? tipo;
  String? metodologia;
  
  // --- NOVOS CAMPOS ---
  Map<String, dynamic>? cliente;
  Map<String, dynamic>? responsavel; // <--- NOVO: Guarda {id: 1, nome: "João"}

  String? escopo;
  List<Map<String, dynamic>> requisitos = [];
  List<Map<String, dynamic>> tecnologias = [];
  List<Map<String, dynamic>> equipe = [];
  List<Map<String, dynamic>> recursos = [];

  DateTime? dataInicio;
  DateTime? dataFinalPrevista;
  DateTime? dataFinal; // conclusão real (mantida ao editar)
  double? orcamentoEstimado;
  String? complexidade;

  // Diagrama de casos de uso gerado no passo de IA do wizard - guardado aqui
  // pra ser salvo (ApiService.criarProjetoCompleto) só depois que o projeto
  // já existe e tem um id. Sem imagem = não salva nada no fim (não força a
  // pessoa a ter gerado um diagrama pra concluir o projeto).
  String? diagramaCasoUsoTitulo;
  String? diagramaCasoUsoMermaid;
  String? diagramaCasoUsoImagemBase64;
  List<String> diagramaCasoUsoAtores = [];

  void clear() {
    id = null;
    nome = null;
    descricao = null;
    modelo = null;
    tipo = null;
    metodologia = null;
    cliente = null;
    responsavel = null; // <--- Limpar
    dataFinal = null;
    escopo = null;
    tecnologias = [];
    equipe = [];
    recursos = [];
    requisitos = [];
    dataInicio = null;
    dataFinalPrevista = null;
    orcamentoEstimado = null;
    complexidade = null;
    diagramaCasoUsoTitulo = null;
    diagramaCasoUsoMermaid = null;
    diagramaCasoUsoImagemBase64 = null;
    diagramaCasoUsoAtores = [];
  }

  void loadFromModel(Projeto p) {
    id = p.id;
    nome = p.nomeProjeto;
    descricao = p.descricao;
    tipo = _normalizarOpcao(p.tipo, ['Web', 'Mobile', 'Desktop', 'API', 'Híbrido', 'Outro']);
    modelo = _normalizarOpcao(p.modeloProjeto, ['SaaS', 'Marketplace', 'E-commerce', 'B2B', 'Institucional', 'Interno', 'Outros']);
    metodologia = p.metodologia;
    escopo = p.escopo;
    dataInicio = p.dataInicio;
    dataFinalPrevista = p.dataFinalPrevisto;
    dataFinal = p.dataFinal;
    orcamentoEstimado = p.orcamentoEstimado;
    complexidade = p.complexidade?.name; 

    // Cliente
    if (p.clienteId != 0) {
      cliente = {
        'id': p.clienteId,
        'razao_social': p.clienteNome ?? 'Cliente Atual'
      };
    }

    // Responsável (Novo)
    if (p.responsavelId != null && p.responsavelId != 0) {
      responsavel = {
        'id': p.responsavelId,
        // Como o Model Projeto básico as vezes não tem o nome do responsável, 
        // colocamos um placeholder que será corrigido pelo Dropdown ao carregar a lista de usuários
        'nome': 'Responsável Atual' 
      };
    }
  }

  /// Corpo enviado a `ApiService.criarProjetoCompleto` ao concluir a criação.
  /// Usado pelo wizard clássico e pelo formulário conversacional.
  Map<String, dynamic> montarPayloadCriacao(int usuarioLogadoId) => {
        "nome_projeto": nome,
        "descricao": descricao,
        "modelo_projeto": modelo,
        "tipo": tipo,
        "escopo": escopo,
        "complexidade": complexidade,
        "cliente_id": cliente?['id'],
        "metodologia": metodologia,
        "data_inicio": dataInicio?.toIso8601String(),
        "data_final_previsto": dataFinalPrevista?.toIso8601String(),
        "orcamento_estimado": orcamentoEstimado,
        "criado_por_id": usuarioLogadoId,
        "responsavel_id":
            responsavel != null ? responsavel!['id'] : usuarioLogadoId,
        "tecnologias": tecnologias.map((t) => t['id']).toList(),
        "equipe": equipe,
        "recursos": recursos.map((r) => r['id']).toList(),
        "requisitos": requisitos.toList(),
        "diagrama_caso_uso_titulo": diagramaCasoUsoTitulo,
        "diagrama_caso_uso_mermaid": diagramaCasoUsoMermaid,
        "diagrama_caso_uso_imagem_base64": diagramaCasoUsoImagemBase64,
        "diagrama_caso_uso_atores": diagramaCasoUsoAtores,
      };

  String? _normalizarOpcao(String? valorBanco, List<String> opcoesDropdown) {
    if (valorBanco == null) return null;
    try {
      return opcoesDropdown.firstWhere(
        (opcao) => opcao.toUpperCase() == valorBanco.toUpperCase()
      );
    } catch (e) {
      // Fora da lista (ex.: 'AI'): mantém o valor para a tela mostrar.
      return valorBanco;
    }
  }
}

final projetoDraft = ProjetoDTO();