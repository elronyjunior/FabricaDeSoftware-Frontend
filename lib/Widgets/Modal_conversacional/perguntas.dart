import 'package:fabrica_software_app/config/projeto_dto.dart';

/// Etapas mostradas na sidebar do modal, na ordem.
enum Etapa {
  gerais('Informações Gerais'),
  requisitos('Requisitos'),
  casoUso('Caso de Uso'),
  equipe('Equipe & Recursos'),
  planejamento('Planejamento');

  const Etapa(this.rotulo);
  final String rotulo;
}

/// Forma que a barra de resposta assume para cada pergunta.
enum ModoResposta {
  /// Texto curto, Enter envia.
  texto,

  /// Texto longo, a barra cresce (Shift+Enter quebra linha).
  textoLongo,

  /// Escolha única em chips, um toque responde.
  escolha,

  /// Chips marcáveis com busca e Confirmar.
  multipla,

  /// Busca com resultados acima da barra.
  busca,

  /// Lista de requisitos: com a IA ativa a barra recebe comandos em texto
  /// livre; desligada, vira o formulário de requisito manual.
  requisitos,

  /// Data (dd/mm/aaaa ou calendário).
  data,

  /// Valor numérico (orçamento).
  numero,

  /// Diagrama gerado pela IA: a barra recebe comandos sobre o diagrama.
  diagrama,
}

/// De onde vêm as opções de uma pergunta de escolha/busca.
enum FonteOpcoes {
  tipos,
  modelos,
  clientes,
  tecnologias,
  contribuidores,
  recursos
}

/// Uma pergunta do formulário conversacional.
///
/// [campo] é a chave do formulário (`projetoDraft`) que a resposta preenche;
/// o valor gravado é do mesmo tipo que o input do wizard clássico grava.
class Pergunta {
  const Pergunta({
    required this.campo,
    required this.etapa,
    required this.texto,
    required this.modo,
    this.rotulo,
    this.dica = 'Digite sua resposta',
    this.obrigatorio = false,
    this.ia = false,
    this.fonte,
    this.sugestoes = const [],
    this.iaInicial = false,
    this.iaFixa = false,
    this.dicaIA,
  });

  final String campo;
  final Etapa etapa;

  /// Texto da pergunta. Pode usar respostas anteriores.
  final String Function(ProjetoDTO dados) texto;

  final ModoResposta modo;

  /// Rótulo curto no topo da barra ("Escolha uma opção").
  final String? rotulo;

  /// Placeholder do campo da barra.
  final String dica;

  final bool obrigatorio;

  /// A pergunta aceita o atalho de IA.
  final bool ia;

  final FonteOpcoes? fonte;

  /// Respostas rápidas mostradas enquanto o campo está vazio.
  final List<String> sugestoes;

  /// A pergunta já abre com o botão de IA ativo (laranja).
  final bool iaInicial;

  /// O botão de IA fica sempre ativo (não há modo manual).
  final bool iaFixa;

  /// Placeholder da barra com a IA ativa.
  final String? dicaIA;
}

// Mesmas opções do passo "Requisitos" do wizard clássico.
const opcoesTipoRequisito = ['Funcional', 'Não Funcional'];
const opcoesPrioridade = ['Alta', 'Média', 'Baixa'];

// Mesmas opções do wizard clássico (Configuracao_Inicial_Projeto_step).
const opcoesTipo = ['Web', 'Mobile', 'Desktop', 'API', 'Híbrido', 'Outro'];
const opcoesModelo = [
  'SaaS',
  'Marketplace',
  'E-commerce',
  'Institucional',
  'Interno',
  'Outros',
];

String _nomeOuProjeto(ProjetoDTO d) =>
    (d.nome ?? '').trim().isEmpty ? 'o projeto' : d.nome!.trim();

/// Ordem fixa das perguntas. Adicionar ou reordenar campos é só editar
/// esta lista.
final List<Pergunta> perguntasCriacao = [
  // ---------------- Informações Gerais ----------------
  Pergunta(
    campo: 'nome',
    etapa: Etapa.gerais,
    texto: (_) => 'Qual o nome do projeto?',
    modo: ModoResposta.texto,
    dica: 'Nome do projeto',
    obrigatorio: true,
  ),
  Pergunta(
    campo: 'metodologia',
    etapa: Etapa.gerais,
    texto: (_) => 'Metodologia Escolhida?',
    modo: ModoResposta.texto,
    dica: 'Ex: Scrum',
    sugestoes: ['Scrum', 'Kanban', 'Cascata', 'XP'],
    ia: true,
  ),
  Pergunta(
    campo: 'tipo',
    etapa: Etapa.gerais,
    texto: (d) => 'Que tipo de projeto é ${_nomeOuProjeto(d)}?',
    modo: ModoResposta.escolha,
    rotulo: 'Escolha uma opção',
    fonte: FonteOpcoes.tipos,
    obrigatorio: true,
  ),
  Pergunta(
    campo: 'modelo',
    etapa: Etapa.gerais,
    texto: (_) => 'Qual o modelo de negócio?',
    modo: ModoResposta.escolha,
    rotulo: 'Escolha uma opção',
    fonte: FonteOpcoes.modelos,
  ),
  Pergunta(
    campo: 'cliente',
    etapa: Etapa.gerais,
    texto: (d) => 'E quem é o cliente de ${_nomeOuProjeto(d)}?',
    modo: ModoResposta.busca,
    rotulo: 'Busque o cliente',
    dica: 'Digite o nome do cliente',
    fonte: FonteOpcoes.clientes,
    obrigatorio: true,
  ),
  Pergunta(
    campo: 'tecnologias',
    etapa: Etapa.gerais,
    texto: (_) => 'Quais tecnologias vão usar?',
    modo: ModoResposta.multipla,
    rotulo: 'Selecione as tecnologias',
    dica: 'Buscar tecnologia',
    fonte: FonteOpcoes.tecnologias,
  ),
  Pergunta(
    campo: 'descricao',
    etapa: Etapa.gerais,
    texto: (_) => 'Qual é o objetivo do projeto?',
    modo: ModoResposta.textoLongo,
    dica: 'Descreva o objetivo',
    ia: true,
  ),

  // ---------------- Requisitos ----------------
  Pergunta(
    campo: 'escopo',
    etapa: Etapa.requisitos,
    texto: (_) => 'Descreva o escopo do projeto para eu gerar os requisitos.',
    modo: ModoResposta.textoLongo,
    dica: 'Descreva o escopo do projeto',
    dicaIA: 'Descreva o escopo: a IA gera os requisitos a partir dele',
    ia: true,
    iaInicial: true,
  ),
  Pergunta(
    campo: 'requisitos',
    etapa: Etapa.requisitos,
    texto: (_) => 'Estes são os requisitos do projeto. Revise, ajuste pela '
        'barra e, quando estiver tudo certo, clique em Próxima etapa.',
    modo: ModoResposta.requisitos,
    dica: 'Título de um novo requisito (Enter para detalhar)',
    dicaIA: 'ex: adicione 3 requisitos de segurança, remova o requisito de '
        'login social',
    obrigatorio: true,
    ia: true,
  ),

  // ---------------- Caso de Uso ----------------
  Pergunta(
    campo: 'diagrama',
    etapa: Etapa.casoUso,
    texto: (_) => 'Vou gerar o diagrama de casos de uso a partir dos '
        'requisitos. Peça ajustes pela barra ou clique em Próxima etapa.',
    modo: ModoResposta.diagrama,
    dicaIA: 'ex: remova o ator Cliente, adicione um caso de uso de '
        'cancelamento',
    ia: true,
    iaFixa: true,
  ),

  // ---------------- Equipe & Recursos ----------------
  Pergunta(
    campo: 'equipe',
    etapa: Etapa.equipe,
    texto: (_) => 'Quem vai fazer parte da equipe?',
    modo: ModoResposta.multipla,
    rotulo: 'Selecione os colaboradores',
    dica: 'Buscar colaborador',
    fonte: FonteOpcoes.contribuidores,
    obrigatorio: true,
  ),
  Pergunta(
    campo: 'recursos',
    etapa: Etapa.equipe,
    texto: (_) => 'Quais recursos serão alocados?',
    modo: ModoResposta.multipla,
    rotulo: 'Selecione os recursos',
    dica: 'Buscar recurso',
    fonte: FonteOpcoes.recursos,
  ),

  // ---------------- Planejamento ----------------
  Pergunta(
    campo: 'dataInicio',
    etapa: Etapa.planejamento,
    texto: (_) => 'Quando o projeto começa?',
    modo: ModoResposta.data,
    dica: 'dd/mm/aaaa',
    obrigatorio: true,
  ),
  Pergunta(
    campo: 'dataFinalPrevista',
    etapa: Etapa.planejamento,
    texto: (_) => 'Qual a data final prevista?',
    modo: ModoResposta.data,
    dica: 'dd/mm/aaaa',
    obrigatorio: true,
  ),
  Pergunta(
    campo: 'orcamentoEstimado',
    etapa: Etapa.planejamento,
    texto: (_) => 'Qual o orçamento estimado?',
    modo: ModoResposta.numero,
    dica: 'R\$ 0,00',
    obrigatorio: true,
    ia: true,
  ),
];
