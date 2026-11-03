import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Chat_IA_Panel.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Modal_step.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Steps/Configuracao_Inicial_Projeto_step/components.dart';
import 'package:fabrica_software_app/providers/modal_criacao_projeto_provider.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fabrica_software_app/config/projeto_dto.dart';
import 'package:fabrica_software_app/services/api_service.dart';

// --- MODELO LOCAL DE DADOS ---
class RequisitoItem {
  String id;
  String titulo;
  String descricao;
  String tipo; // 'Funcional' ou 'Não Funcional'
  String prioridade; // 'Alta', 'Média', 'Baixa'
  bool isAiGenerated;
  bool isEdited;
  bool isApproved;

  RequisitoItem({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.tipo,
    required this.prioridade,
    this.isAiGenerated = false,
    this.isEdited = false,
    this.isApproved = true, // Manuais nascem aprovados, IA requer aprovação
  });
}

class LevantamentosRequisitosStep extends ModalStep {
  @override
  String get title => 'Requisitos & Stack Tecnológico';

  @override
  String get tabName => 'Requisitos';

  @override
  String get ajuda =>
      'Descreva o escopo do projeto e gere os requisitos com IA, ou adicione manualmente. Depois, ajuste a lista pelo assistente de IA. É preciso ter ao menos um requisito.';

  @override
  IconData get icon => FontAwesomeIcons.listCheck;

  @override
  List<Color> get cores => <Color>[Colors.blueAccent, Colors.purpleAccent];

  // Layout próprio (conteúdo + painel de chat) - ver Modal_step.dart e
  // Modal_de_criacao.dart.
  @override
  bool get temPainelProprio => true;

  @override
  bool validar() => _contentKey.currentState?.validar() ?? true;

  @override
  void salvar() => _contentKey.currentState?.salvarNoDTO();

  final GlobalKey<_LevantamentoRequisitosContentState> _contentKey =
      GlobalKey();

  @override
  Widget buildBody(BuildContext context) {
    return _LevantamentoRequisitosContent(key: _contentKey);
  }

  @override
  Widget buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botão Cancelar
          TextButton.icon(
            onPressed: () {
              // Regra: Sair perde tudo
              projetoDraft.clear();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close, size: 16, color: Colors.black87),
            label: const Text('Cancelar',
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.normal)),
          ),

          Row(
            children: [
              // Botão Voltar
              OutlinedButton(
                onPressed: () {
                  // Regra: Regressar perde o progresso desta etapa
                  if (_contentKey.currentState != null) {
                    _contentKey.currentState!.limparDadosDestaEtapa();
                  }
                  context.read<ModalCriacaoProjetoProvider>().previousIndex();
                },
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Voltar',
                    style: TextStyle(color: Colors.black87)),
              ),

              const SizedBox(width: 12),

              // Botão Próxima Etapa
              ElevatedButton(
                onPressed: () {
                  if (_contentKey.currentState != null) {
                    // Validação: Só avança se tiver requisitos
                    if (_contentKey.currentState!.validar()) {
                      _contentKey.currentState!.salvarNoDTO();
                      context.read<ModalCriacaoProjetoProvider>().nextIndex();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Row(
                  children: const [
                    Text('Próxima etapa'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevantamentoRequisitosContent extends StatefulWidget {
  const _LevantamentoRequisitosContent({super.key});

  @override
  State<_LevantamentoRequisitosContent> createState() =>
      _LevantamentoRequisitosContentState();
}

class _LevantamentoRequisitosContentState
    extends State<_LevantamentoRequisitosContent> {
  // --- ASSISTENTE EM PAINEL FILHO ---
  // Dentro do modal de criação, o chat abre ao lado do modal (painel filho)
  // em vez de ocupar espaço aqui. Fora dele, continua no próprio layout.
  AssistenteIdv? _assistente;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _assistente = EscopoAssistenteIdv.maybeOf(context);
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    // O painel filho desenha o chat com o estado desta aba.
    if (_assistente?.aberto ?? false) _assistente!.atualizar();
  }

  void _registrarAssistente(String dono, bool disponivel) {
    final assistente = _assistente;
    if (assistente == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        assistente.registrar(dono, disponivel ? _chatFilho : null);
      }
    });
  }

  Widget _chatFilho(BuildContext context) => ChatIAPanel(
        mensagens: _mensagensChat,
        isLoading: _isConversando,
        onEnviar: _enviarMensagemChat,
        raio: 28,
        aoFechar: _assistente?.fechar,
        subtitulo: 'Crio e ajusto os requisitos do projeto.',
        placeholder: 'Peça um ajuste nos requisitos...',
        sugestoes: const [
          'Sugira requisitos a partir do escopo',
          'Adicione requisitos de segurança',
          'Revise as prioridades da lista',
        ],
      );

  // Controladores
  final TextEditingController _escopoController = TextEditingController();
  final TextEditingController _novoTituloController = TextEditingController();
  final TextEditingController _novaDescricaoController =
      TextEditingController();

  String _tipoSelecionado = 'Funcional';
  String _prioridadeSelecionada = 'Média';
  bool _isLoadingAI = false;

  // Lista de requisitos local
  final List<RequisitoItem> requisitos = [];

  // Chat de IA com memória - independente do botão "Gerar Requisitos com
  // IA" (que continua um disparo único a partir do escopo). Sessão própria
  // deste passo, sem relação com a sessão do passo de Diagrama.
  String? _chatSessionId;
  bool _isConversando = false;
  final List<ChatMensagem> _mensagensChat = [];

  // --- MÉTODOS DE CONTROLE ---

  void limparDadosDestaEtapa() {
    setState(() {
      requisitos.clear();
      projetoDraft.requisitos = [];
      _escopoController.clear();
      _novoTituloController.clear();
      _novaDescricaoController.clear();
      _chatSessionId = null;
      _mensagensChat.clear();
    });
  }

  void salvarNoDTO() {
    projetoDraft.escopo = _escopoController.text;

    projetoDraft.requisitos = requisitos
        .map((r) => {
              'titulo': r.titulo,
              'descricao': r.descricao,
              'tipo': r.tipo,
              'prioridade': r.prioridade,
              'is_ai_generated': r.isAiGenerated,
              'is_approved': r.isApproved,
              'is_edited': r.isEdited
            })
        .toList();
  }

  bool validar() {
    if (requisitos.isEmpty) {
      avisar(context, 'Adicione pelo menos um requisito para continuar.');
      return false;
    }
    return true;
  }

  void _adicionarRequisitoManual() {
    if (_novoTituloController.text.trim().isEmpty ||
        _novaDescricaoController.text.trim().isEmpty) return;

    setState(() {
      requisitos.add(RequisitoItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        titulo: _novoTituloController.text,
        descricao: _novaDescricaoController.text,
        tipo: _tipoSelecionado,
        prioridade: _prioridadeSelecionada,
        isAiGenerated: false,
        isApproved: true, // Manuais já nascem aprovados
      ));

      _novoTituloController.clear();
      _novaDescricaoController.clear();
    });
  }

  // --- INTEGRAÇÃO COM IA NO BACKEND ---
  Future<void> _gerarRequisitosIA() async {
    if (_escopoController.text.trim().isEmpty) {
      avisar(context, 'Descreva o escopo do projeto antes de chamar a IA.',
          tipo: TipoAviso.info);
      return;
    }

    setState(() => _isLoadingAI = true);

    try {
      String nomeProjeto = projetoDraft.nome ?? "Novo Projeto";

      // Chama o ApiService que conecta no seu Node.js
      List<dynamic> resultados = await ApiService.gerarRequisitosBackend(
          _escopoController.text, nomeProjeto);

      setState(() {
        for (var item in resultados) {
          requisitos.add(RequisitoItem(
            id: DateTime.now().microsecondsSinceEpoch.toString() +
                item['titulo'].hashCode.toString(),
            titulo: item['titulo'] ?? 'Requisito Sugerido',
            descricao: item['descricao'] ?? '',
            tipo: item['tipo'] ?? 'Funcional',
            prioridade: item['prioridade'] ?? 'Média',
            isAiGenerated: true,
            isApproved: false, // Requer aprovação
          ));
        }
      });
    } catch (e) {
      if (mounted) avisar(context, mensagemErroIa(e));
    } finally {
      setState(() => _isLoadingAI = false);
    }
  }

  // Mensagem enviada pelo chat: sempre manda a lista ATUAL de requisitos (a
  // pessoa pode ter editado manualmente desde a última mensagem) e recebe de
  // volta a lista COMPLETA já atualizada - por isso a reconciliação abaixo,
  // em vez de simplesmente substituir a lista local.
  Future<void> _enviarMensagemChat(String mensagem) async {
    if (_isConversando) return;

    setState(() {
      _mensagensChat.add(ChatMensagem(texto: mensagem, deUsuario: true));
      _isConversando = true;
    });

    try {
      final nomeProjeto = projetoDraft.nome ?? 'Novo Projeto';
      final requisitosAtuais = requisitos
          .map((r) => {
                'titulo': r.titulo,
                'descricao': r.descricao,
                'tipo': r.tipo,
                'prioridade': r.prioridade
              })
          .toList();

      final resultado = await ApiService.chatRequisitos(
        sessionId: _chatSessionId,
        mensagem: mensagem,
        nomeProjeto: nomeProjeto,
        escopo: _escopoController.text,
        requisitosAtuais: requisitosAtuais,
      );

      final novaLista = _reconciliarRequisitos(
          resultado['requisitos'] as List<dynamic>? ?? []);
      final respostaChat = resultado['resposta_chat'] as String?;

      setState(() {
        _chatSessionId = resultado['sessionId'] as String? ?? _chatSessionId;
        requisitos
          ..clear()
          ..addAll(novaLista);
        if (respostaChat != null && respostaChat.trim().isNotEmpty) {
          _mensagensChat
              .add(ChatMensagem(texto: respostaChat, deUsuario: false));
        }
      });
    } catch (e) {
      setState(() => _mensagensChat
          .add(ChatMensagem(texto: mensagemErroIa(e), deUsuario: false)));
    } finally {
      if (mounted) setState(() => _isConversando = false);
    }
  }

  // Casa cada item devolvido pela IA com um já existente (por título +
  // descrição idênticos) pra preservar id/aprovação/edição de quem não foi
  // tocado. Sem correspondência = item novo da IA (precisa aprovação). Um
  // item que existia mas não veio na resposta foi removido a pedido do chat
  // - a IA sempre devolve a lista completa, então ausência = remoção.
  List<RequisitoItem> _reconciliarRequisitos(List<dynamic> novosDoBackend) {
    return novosDoBackend.map((item) {
      final titulo = (item['titulo'] as String?) ?? 'Requisito';
      final descricao = (item['descricao'] as String?) ?? '';
      final existente = _buscarRequisitoExistente(titulo, descricao);

      if (existente != null) return existente;

      return RequisitoItem(
        id: DateTime.now().microsecondsSinceEpoch.toString() +
            titulo.hashCode.toString(),
        titulo: titulo,
        descricao: descricao,
        tipo: (item['tipo'] as String?) ?? 'Funcional',
        prioridade: (item['prioridade'] as String?) ?? 'Média',
        isAiGenerated: true,
        isApproved: false, // Requer aprovação, como qualquer sugestão da IA
      );
    }).toList();
  }

  RequisitoItem? _buscarRequisitoExistente(String titulo, String descricao) {
    for (final r in requisitos) {
      if (r.titulo == titulo && r.descricao == descricao) return r;
    }
    return null;
  }

  // --- LÓGICA DE EDIÇÃO (dentro do próprio card) ---

  /// Cards abertos (mostram a descrição) e o card em edição.
  final Set<String> _abertos = {};
  String? _editandoId;
  final _editTituloCtrl = TextEditingController();
  final _editDescCtrl = TextEditingController();
  String _editTipo = 'Funcional';
  String _editPrioridade = 'Média';

  void _alternarAberto(RequisitoItem req) {
    setState(() {
      if (!_abertos.remove(req.id)) _abertos.add(req.id);
    });
  }

  void _editarRequisito(RequisitoItem req) {
    setState(() {
      _editandoId = req.id;
      _editTituloCtrl.text = req.titulo;
      _editDescCtrl.text = req.descricao;
      _editTipo = req.tipo;
      _editPrioridade = req.prioridade;
    });
  }

  void _salvarEdicao(RequisitoItem req) {
    if (_editTituloCtrl.text.trim().isEmpty) {
      avisar(context, 'O requisito precisa de um título.');
      return;
    }
    setState(() {
      req.titulo = _editTituloCtrl.text.trim();
      req.descricao = _editDescCtrl.text.trim();
      req.tipo = _editTipo;
      req.prioridade = _editPrioridade;
      req.isEdited = true;
      _editandoId = null;
    });
  }

  void _removerRequisito(RequisitoItem req) {
    setState(() {
      requisitos.remove(req);
      _abertos.remove(req.id);
      if (_editandoId == req.id) _editandoId = null;
    });
  }

  void _toggleAprovacao(RequisitoItem req) {
    setState(() => req.isApproved = !req.isApproved);
  }

  @override
  void dispose() {
    _editTituloCtrl.dispose();
    _editDescCtrl.dispose();
    _escopoController.dispose();
    _novoTituloController.dispose();
    _novaDescricaoController.dispose();
    super.dispose();
  }

  static const _tipos = ['Funcional', 'Não Funcional'];
  static const _prioridades = ['Alta', 'Média', 'Baixa'];

  /// A lista e o assistente de IA só aparecem depois do escopo: quando já
  /// há requisitos (gerados ou manuais) ou a pessoa escolheu o modo manual.
  bool _modoManual = false;
  bool get _liberado => requisitos.isNotEmpty || _modoManual;

  @override
  Widget build(BuildContext context) {
    _registrarAssistente('Requisitos', true);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      child: _liberado ? _layoutCompleto() : _layoutEscopo(),
    );
  }

  Widget _layoutEscopo() {
    return SingleChildScrollView(
      key: const ValueKey('escopo'),
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _blocoEscopo(),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _modoManual = true),
              style: TextButton.styleFrom(
                  foregroundColor: CoresIdv.textoSecundario),
              child: Text('Prefiro adicionar os requisitos manualmente',
                  style: fonteIdv(
                      tamanho: 13,
                      peso: FontWeight.w500,
                      cor: CoresIdv.textoSecundario)),
            ),
          ),
        ],
      ),
    );
  }

  /// Escopo em cima, com a largura toda; embaixo, a lista de requisitos
  /// e o assistente de IA lado a lado (empilhados em telas estreitas).
  Widget _layoutCompleto() {
    final chat = SizedBox(
      height: 520,
      child: ChatIAPanel(
        mensagens: _mensagensChat,
        isLoading: _isConversando,
        onEnviar: _enviarMensagemChat,
        placeholder:
            'ex: adicione 3 requisitos de segurança, remova o requisito de login social...',
      ),
    );

    return SingleChildScrollView(
      key: const ValueKey('completo'),
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _blocoEscopo(),
          const SizedBox(height: 28),
          LayoutBuilder(builder: (context, c) {
            // Com o painel filho, a lista fica com a largura toda.
            if (_assistente != null) return _listaRequisitos();
            if (c.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _listaRequisitos(),
                  const SizedBox(height: 20),
                  chat
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _listaRequisitos()),
                const SizedBox(width: 20),
                SizedBox(width: 340, child: chat),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String hint,
      {int maxLines = 1, required int limite}) {
    return Container(
      decoration: ComponentsConfiguracaoInicalProjeto.inputBoxDecoration,
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        inputFormatters: textoIdv(limite),
        style: fonteIdv(),
        decoration: ComponentsConfiguracaoInicalProjeto.inputDecoration(hint),
      ),
    );
  }

  /// Tipo e prioridade como botões de escolha, com rótulo em cima.
  Widget _tipoEPrioridade({
    required String tipo,
    required String prioridade,
    required ValueChanged<String> aoMudarTipo,
    required ValueChanged<String> aoMudarPrioridade,
  }) {
    Widget escolha(String rotulo, String valor, List<String> opcoes,
        ValueChanged<String> aoMudar) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(rotulo,
                  style: fonteIdv(
                      tamanho: 12,
                      peso: FontWeight.w600,
                      cor: CoresIdv.textoSecundario)),
            ),
            SelecaoIdv<String>(
              hint: rotulo,
              valor: valor,
              itens: opcoes,
              rotulo: (e) => e,
              aoMudar: (v) {
                if (v != null) aoMudar(v);
              },
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        escolha('Tipo', tipo, _tipos, aoMudarTipo),
        const SizedBox(width: 12),
        escolha('Prioridade', prioridade, _prioridades, aoMudarPrioridade),
      ],
    );
  }

  Widget _blocoEscopo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComponentsConfiguracaoInicalProjeto.buildLabel('Escopo do projeto',
            isRequired: true),
        _campo(
          _escopoController,
          'Ex: Desenvolver um CRM para gestão de vendas com integração ao WhatsApp...',
          maxLines: 4,
          limite: LimitesIdv.escopo,
        ),
        const SizedBox(height: 12),
        BotaoIa(
          rotulo: requisitos.isEmpty
              ? 'Gerar requisitos com IA'
              : 'Gerar mais requisitos com IA',
          rotuloCarregando: 'Gerando requisitos...',
          carregando: _isLoadingAI,
          aoTocar: _gerarRequisitosIA,
        ),
      ],
    );
  }

  Widget _listaRequisitos() {
    final countFuncional =
        requisitos.where((r) => r.tipo == 'Funcional').length;
    final countNaoFuncional = requisitos.length - countFuncional;
    String plural(int n, String um, String varios) => n == 1 ? um : varios;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Requisitos', style: fonteIdv(tamanho: 16, peso: FontWeight.w700)),
        const SizedBox(height: 12),

        // --- CADASTRO MANUAL ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CoresIdv.borda),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Adicionar manualmente',
                  style: fonteIdv(
                      tamanho: 13,
                      peso: FontWeight.w600,
                      cor: CoresIdv.textoSecundario)),
              const SizedBox(height: 12),
              _campo(_novoTituloController, 'Título (ex: Login social)',
                  limite: LimitesIdv.tituloRequisito),
              const SizedBox(height: 8),
              _campo(_novaDescricaoController, 'Descrição detalhada...',
                  limite: LimitesIdv.descricaoRequisito),
              const SizedBox(height: 12),
              _tipoEPrioridade(
                tipo: _tipoSelecionado,
                prioridade: _prioridadeSelecionada,
                aoMudarTipo: (v) => setState(() => _tipoSelecionado = v),
                aoMudarPrioridade: (v) =>
                    setState(() => _prioridadeSelecionada = v),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _adicionarRequisitoManual,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Adicionar requisito'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CoresIdv.azul,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: fonteIdv(peso: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- RESUMO + LISTA DE CARDS ---
        if (requisitos.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Nenhum requisito ainda.\nGere com a IA ou adicione manualmente.',
              textAlign: TextAlign.center,
              style: fonteIdv(cor: CoresIdv.textoSecundario, altura: 1.5),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${requisitos.length} ${plural(requisitos.length, 'requisito', 'requisitos')}'
              '  ·  $countFuncional ${plural(countFuncional, 'funcional', 'funcionais')}'
              '  ·  $countNaoFuncional ${plural(countNaoFuncional, 'não funcional', 'não funcionais')}',
              style: fonteIdv(
                  tamanho: 13,
                  peso: FontWeight.w500,
                  cor: CoresIdv.textoSecundario),
            ),
          ),
          ...requisitos.map(_buildRequisitoCard),
        ],
      ],
    );
  }

  Color _corPrioridade(String prioridade) {
    switch (prioridade) {
      case 'Alta':
        return CoresIdv.vermelho;
      case 'Média':
        return CoresIdv.laranja;
      default:
        return CoresIdv.verde;
    }
  }

  Widget _buildRequisitoCard(RequisitoItem req) {
    final editando = _editandoId == req.id;
    final aberto = editando || _abertos.contains(req.id);

    return AnimatedContainer(
      key: ValueKey(req.id),
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: editando
              ? CoresIdv.azul
              : req.isApproved
                  ? CoresIdv.verde.withOpacity(0.55)
                  : CoresIdv.borda,
          width: editando || req.isApproved ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: editando ? _cardEditando(req) : _cardLeitura(req, aberto),
      ),
    );
  }

  /// Modo fechado: título, etiquetas e ações numa linha. Aberto: descrição.
  Widget _cardLeitura(RequisitoItem req, bool aberto) {
    final corTipo = req.tipo == 'Funcional' ? CoresIdv.azul : CoresIdv.laranja;

    return InkWell(
      onTap: () => _alternarAberto(req),
      hoverColor: const Color(0x060F1030),
      splashColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AnimatedRotation(
                  turns: aberto ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.chevron_right_rounded,
                      size: 20, color: CoresIdv.textoSecundario),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(req.titulo,
                      maxLines: aberto ? 3 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: fonteIdv(tamanho: 14, peso: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                TagIdv(texto: req.tipo, cor: corTipo),
                const SizedBox(width: 6),
                TagIdv(
                    texto: req.prioridade, cor: _corPrioridade(req.prioridade)),
                const SizedBox(width: 6),
                Tooltip(
                  message: req.isAiGenerated ? 'Gerado pela IA' : 'Manual',
                  child: Icon(
                      req.isAiGenerated
                          ? FontAwesomeIcons.wandMagicSparkles
                          : Icons.person_outline_rounded,
                      size: 13,
                      color: req.isAiGenerated
                          ? CoresIdv.laranja
                          : CoresIdv.textoSecundario),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: req.isApproved ? 'Aprovado' : 'Aprovar',
                  onPressed: () => _toggleAprovacao(req),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                      req.isApproved
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 20,
                      color: req.isApproved
                          ? CoresIdv.verde
                          : CoresIdv.textoSecundario),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: () => _editarRequisito(req),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined,
                      size: 19, color: CoresIdv.textoSecundario),
                ),
                IconButton(
                  tooltip: 'Remover',
                  onPressed: () => _removerRequisito(req),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 19, color: CoresIdv.vermelho),
                ),
              ],
            ),
            if (aberto)
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 2, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        req.descricao.isEmpty
                            ? 'Sem descrição.'
                            : req.descricao,
                        style: fonteIdv(
                            tamanho: 13,
                            cor: CoresIdv.textoSecundario,
                            altura: 1.5)),
                    if (req.isEdited) ...[
                      const SizedBox(height: 8),
                      const TagIdv(
                          texto: 'Editado', cor: CoresIdv.textoSecundario),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Modo edição: os campos aparecem dentro do próprio card.
  Widget _cardEditando(RequisitoItem req) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _campo(_editTituloCtrl, 'Título', limite: LimitesIdv.tituloRequisito),
          const SizedBox(height: 8),
          _campo(_editDescCtrl, 'Descrição',
              maxLines: 3, limite: LimitesIdv.descricaoRequisito),
          const SizedBox(height: 10),
          _tipoEPrioridade(
            tipo: _editTipo,
            prioridade: _editPrioridade,
            aoMudarTipo: (v) => setState(() => _editTipo = v),
            aoMudarPrioridade: (v) => setState(() => _editPrioridade = v),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _editandoId = null),
                style: TextButton.styleFrom(
                    foregroundColor: CoresIdv.textoSecundario),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _salvarEdicao(req),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CoresIdv.azul,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
