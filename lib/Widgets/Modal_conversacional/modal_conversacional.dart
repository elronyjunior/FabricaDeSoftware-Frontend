import 'dart:math' as math;

import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/config/projeto_dto.dart';
import 'package:fabrica_software_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'barra_resposta.dart';
import 'componentes_documentos.dart';
import 'controlador_conversa.dart';
import 'estilo_conversa.dart';
import 'perguntas.dart';

/// Abre o formulário conversacional de criação de projeto, cobrindo a
/// janela inteira (inclusive o menu lateral fixo).
/// Completa quando o modal fecha (criado ou cancelado).
Future<void> abrirModalConversacional(BuildContext context) {
  projetoDraft.clear();
  return CamadaModal.abrir(const ModalConversacional());
}

/// Largura máxima da coluna da conversa (mensagens e barra), centralizada
/// como num chat: espaço dos dois lados e mensagens mais próximas.
const double _larguraColuna = 700;

/// Largura da barra lateral do modal fechada (só os ícones) e aberta.
const double _larguraLateral = 56;
const double _larguraLateralAberta = 236;

class ModalConversacional extends StatefulWidget {
  const ModalConversacional({super.key});

  @override
  State<ModalConversacional> createState() => _ModalConversacionalState();
}

class _ModalConversacionalState extends State<ModalConversacional> {
  final _conversa = ControladorConversa();
  final _rolagem = ScrollController();

  // Chaves para rolar o chat até um card ou até o início de uma etapa.
  final Map<String, GlobalKey> _chavesCards = {};
  final Map<Etapa, GlobalKey> _chavesEtapas = {
    for (final e in Etapa.values) e: GlobalKey()
  };
  int _ultimaVersaoChat = -1;

  /// O chat está "preso" no fim: quando a barra cresce ou encolhe, ele
  /// continua mostrando a última mensagem. Solta assim que o usuário rola
  /// para cima (com a roda do mouse, arrastando ou pela barra lateral).
  bool _presoNoFim = true;

  /// Rolagem feita pelo próprio modal (não conta como rolagem do usuário).
  bool _rolandoSozinho = false;

  /// O usuário subiu a conversa: mostra o botão de ir para o fim.
  bool _longeDoFim = false;

  String? _erroProximaEtapa;

  ControladorConversa get c => _conversa;

  @override
  void initState() {
    super.initState();
    _conversa.addListener(_aoMudarConversa);
    _rolagem.addListener(_atualizarBotaoDescer);
    _conversa.carregarOpcoes();
  }

  @override
  void dispose() {
    _conversa.removeListener(_aoMudarConversa);
    _conversa.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Rolagem
  // ---------------------------------------------------------------------

  void _aoMudarConversa() {
    // Rola até o fim só quando entra um balão novo ou a pergunta avança
    // (aprovar ou abrir um card não mexe na rolagem).
    if (_conversa.versaoChat != _ultimaVersaoChat) {
      _ultimaVersaoChat = _conversa.versaoChat;
      _erroProximaEtapa = null;
      _rolarParaFim();
    }
    final card = _conversa.consumirRolagem();
    if (card != null) _rolarAte(_chavesCards[card], alinhamento: 0.3);
  }

  void _atualizarBotaoDescer() {
    if (!_rolagem.hasClients) return;
    final pos = _rolagem.position;
    final longe = pos.maxScrollExtent - pos.pixels > 120;
    if (longe != _longeDoFim) setState(() => _longeDoFim = longe);
  }

  /// Botão de descer: volta para a última mensagem e prende o chat no fim.
  void _irParaFim() {
    if (!_rolagem.hasClients) return;
    _presoNoFim = true;
    _animar(_rolagem.position.maxScrollExtent);
  }

  /// Qualquer rolagem do usuário decide se o chat continua preso no fim.
  bool _aoRolarChat(ScrollNotification n) {
    if (!_rolandoSozinho && n is ScrollUpdateNotification) {
      final pos = n.metrics;
      _presoNoFim = pos.pixels >= pos.maxScrollExtent - 24;
    }
    return false;
  }

  /// A área do chat mudou de tamanho (barra cresceu/encolheu, card abriu).
  bool _aoMudarTamanhoChat(ScrollMetricsNotification n) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _atualizarBotaoDescer();
    });
    if (_presoNoFim) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_rolagem.hasClients || !_presoNoFim) return;
        final fim = _rolagem.position.maxScrollExtent;
        if ((_rolagem.offset - fim).abs() > 1) _pular(fim);
      });
    }
    return false;
  }

  void _pular(double posicao) {
    _rolandoSozinho = true;
    _rolagem.jumpTo(posicao);
    _rolandoSozinho = false;
  }

  Future<void> _animar(double posicao) async {
    _rolandoSozinho = true;
    try {
      await _rolagem.animateTo(
        posicao,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _rolandoSozinho = false;
    }
  }

  void _rolarAte(GlobalKey? chave, {double alinhamento = 0}) {
    _presoNoFim = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = chave?.currentContext;
      if (ctx == null) return;
      _rolandoSozinho = true;
      try {
        await Scrollable.ensureVisible(
          ctx,
          alignment: alinhamento,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } finally {
        _rolandoSozinho = false;
      }
    });
  }

  /// Etapa clicada na barra lateral: vai para a primeira mensagem dela.
  void _irParaEtapa(Etapa etapa) {
    if (!_conversa.etapaAlcancada(etapa)) return;
    if (_conversa.documentoAberto != null) _conversa.fecharDocumento();
    _rolarAte(_chavesEtapas[etapa]);
  }

  /// Mantém a última pergunta visível. Roda de novo depois da animação da
  /// barra (~200 ms), que muda a altura do chat.
  void _rolarParaFim() {
    _presoNoFim = true;
    void rolar() {
      if (!mounted || !_rolagem.hasClients || !_presoNoFim) return;
      _animar(_rolagem.position.maxScrollExtent);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => rolar());
    Future.delayed(const Duration(milliseconds: 260), rolar);
  }

  // ---------------------------------------------------------------------
  // Ações
  // ---------------------------------------------------------------------

  Future<void> _fechar() async {
    final sair = await mostrarConfirmacao(
      context,
      titulo: 'Sair da criação do projeto?',
      mensagem: 'Tem certeza que deseja sair? As respostas ainda não salvas '
          'serão perdidas.',
      confirmar: 'Sair',
      perigo: true,
    );
    if (sair == true && mounted) {
      projetoDraft.clear();
      CamadaModal.fechar();
    }
  }

  Future<void> _criarProjeto() async {
    final usuario = context.read<AuthProvider>().userId;
    final mensageiro = ScaffoldMessenger.of(context);
    final ok = await _conversa.criarProjeto(usuario);
    if (!ok || !mounted) return;
    CamadaModal.fechar();
    mensageiro.showSnackBar(const SnackBar(
      content: Text('Projeto criado!'),
      backgroundColor: Colors.green,
    ));
    projetoDraft.clear();
  }

  /// "Próxima etapa" aparece fora da barra, nas etapas em que a resposta é
  /// um bloco (requisitos e diagrama).
  bool get _mostraProximaEtapa {
    final p = c.perguntaAtiva;
    return c.documentoAberto == null &&
        c.editando == null &&
        c.indiceAtivo == c.indiceAtual &&
        (p?.modo == ModoResposta.requisitos ||
            p?.modo == ModoResposta.diagrama);
  }

  Future<void> _proximaEtapa() async {
    final p = c.perguntaAtiva;
    if (p == null || c.gerando) return;
    if (p.modo == ModoResposta.diagrama) {
      c.continuar();
      return;
    }

    final pendentes = c.requisitosPendentes;
    if (c.dados.requisitos.isNotEmpty && pendentes > 0) {
      final total = c.contagemRequisitos.total;
      final continuar = await mostrarConfirmacao(
        context,
        titulo: 'Requisitos pendentes',
        mensagem: 'Nem todos os requisitos foram aprovados. $pendentes de '
            '$total ainda ${pendentes == 1 ? 'está pendente' : 'estão pendentes'}.',
        cancelar: 'Voltar e revisar',
        confirmar: 'Continuar e aprovar todos',
      );
      if (!mounted) return;
      if (continuar != true) {
        c.revisarPendentes();
        return;
      }
    }
    setState(() => _erroProximaEtapa = c.avancarRequisitos());
  }

  // ---------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    const largura = EstiloConversa.largura + _larguraLateral;
    // O modal ocupa quase toda a janela; a altura acompanha a tela.
    var escala = math.min(tela.width * 0.92 / largura, 1.6);
    var altura = tela.height * 0.88 / escala;
    if (altura < 560) {
      altura = 560;
      escala = tela.height * 0.88 / altura;
    }
    altura = math.min(altura, 820);

    return Center(
      child: SizedBox(
        width: largura * escala,
        height: altura * escala,
        child: FittedBox(
          child: SizedBox(
            width: largura,
            height: altura,
            child: Material(
              type: MaterialType.transparency,
              child: ListenableBuilder(
                listenable: _conversa,
                builder: (context, _) => _cartao(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cartao() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(EstiloConversa.raio),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 40, offset: Offset(0, 16)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EstiloConversa.raio),
        // Um fundo só para o chat e a barra lateral: ela faz parte do modal.
        child: DecoratedBox(
          decoration:
              const BoxDecoration(gradient: EstiloConversa.fundoConversa),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _areaConversa()),
              // Fechada: só os ícones. Ao abrir, o chat encolhe para dar
              // espaço (não fica nada por cima do conteúdo).
              _BarraLateralModal(conversa: c, onEtapa: _irParaEtapa),
            ],
          ),
        ),
      ),
    );
  }

  Widget _areaConversa() {
    final doc = c.documentoAberto;
    return DecoratedBox(
      decoration: const BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progresso + fechar
          SizedBox(
            height: 50,
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(child: _BarraProgresso(valor: c.progresso)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(c.progresso * 100).round()}%',
                    style: EstiloConversa.fonte(
                        tamanho: 9,
                        peso: FontWeight.w500,
                        cor: Colors.white.withOpacity(0.9)),
                  ),
                ),
                const SizedBox(width: 40),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: c.enviando ? null : _fechar,
                  icon: const Icon(Icons.close_rounded,
                      size: 26, color: Colors.white, weight: 700),
                ),
                const SizedBox(width: 7),
              ],
            ),
          ),
          // Nome da etapa atual, logo abaixo do progresso.
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              layoutBuilder: (atual, anteriores) => Stack(
                alignment: Alignment.centerLeft,
                children: [...anteriores, if (atual != null) atual],
              ),
              child: Text(
                c.etapaAtual.rotulo,
                key: ValueKey(c.etapaAtual),
                style: EstiloConversa.fonte(tamanho: 17, peso: FontWeight.w600),
              ),
            ),
          ),

          // Conversa (ou o documento aberto por cima dela)
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Offstage(
                    offstage: doc != null,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      // Clicar em algo dentro do chat (editar ou abrir um
                      // card) solta o chat do fim: o conteúdo pode crescer
                      // sem a rolagem descer sozinha.
                      child: Listener(
                        onPointerDown: (_) => _presoNoFim = false,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _aoRolarChat,
                          child:
                              NotificationListener<ScrollMetricsNotification>(
                            onNotification: _aoMudarTamanhoChat,
                            // Todas as mensagens ficam montadas (não só as
                            // visíveis), para a barra lateral e o "Voltar e
                            // revisar" conseguirem rolar até qualquer uma.
                            child: SingleChildScrollView(
                              controller: _rolagem,
                              padding:
                                  const EdgeInsets.fromLTRB(36, 28, 36, 24),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: _larguraColuna),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: _baloes(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (doc == null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Center(
                      child: _BotaoDescer(
                        visivel: _longeDoFim,
                        onTap: _irParaFim,
                      ),
                    ),
                  ),
                if (doc != null) Positioned.fill(child: _documento(doc)),
              ],
            ),
          ),

          // Barra de resposta + Próxima etapa / Salvar rascunho
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 0, 36, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _larguraColuna),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: BarraResposta(
                        controlador: c,
                        alturaMaxima: 240,
                        onProximaEtapa:
                            _mostraProximaEtapa ? _proximaEtapa : null,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3.5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_erroProximaEtapa != null) ...[
                            SizedBox(
                              width: 150,
                              child: Text(_erroProximaEtapa!,
                                  textAlign: TextAlign.right,
                                  style: EstiloConversa.fonte(
                                      tamanho: 11, cor: Colors.red.shade700)),
                            ),
                            const SizedBox(height: 6),
                          ],
                          _BotaoLateral(
                            texto: 'Salvar Rascunho',
                            cor: EstiloConversa.laranja,
                            onPressed: c.temResposta
                                ? () => c.salvarRascunho(projetoDraft)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _baloes() {
    final itens = <Widget>[];
    final ultima = math.min(c.indiceAtual, c.perguntas.length - 1);

    for (var i = 0; i <= ultima; i++) {
      final p = c.perguntas[i];
      final primeiraDaEtapa = i == 0 || c.perguntas[i - 1].etapa != p.etapa;
      itens.add(_BalaoSistema(
        key: primeiraDaEtapa ? _chavesEtapas[p.etapa] : null,
        texto: p.texto(c.dados),
        destaque: c.editando == i,
      ));

      for (final extra in c.extras(i)) {
        itens.add(_balaoExtra(extra, ativa: i == c.indiceAtivo));
      }

      if (c.respondida(i)) {
        itens.add(_BalaoUsuario(
          texto: c.textoResposta(i),
          pulada: c.pulada(i),
          onEditar: c.enviando ? null : () => c.editar(i),
        ));
      }
    }

    if (c.concluido) {
      itens.add(_CardResumo(
        conversa: c,
        onCriar: _criarProjeto,
      ));
      if (c.erroEnvio != null) {
        itens.add(_BalaoSistema(texto: c.erroEnvio!, erro: true));
      }
    }
    return itens;
  }

  Widget _balaoExtra(MensagemExtra m, {required bool ativa}) {
    switch (m.tipo) {
      case TipoExtra.pedidoIA:
      case TipoExtra.pedidoAjuste:
        return _BalaoUsuario(texto: m.texto, ia: true);
      case TipoExtra.carregando:
        return _BalaoCarregando(texto: m.texto);
      case TipoExtra.erro:
        return _BalaoSistema(texto: m.texto, erro: true);
      case TipoExtra.sistema:
        return _BalaoSistema(texto: m.texto);
      case TipoExtra.resumoRequisitos:
        return _BalaoSistema(
          texto: m.texto,
          acao: c.podeDesfazer(m) && !c.gerando
              ? ('Desfazer', () => c.desfazer(m))
              : null,
        );
      case TipoExtra.blocoRequisitos:
        return BlocoRequisitos(
          controlador: c,
          chavesCards: _chavesCards,
        );
      case TipoExtra.cardDiagrama:
        return CardDiagrama(
          controlador: c,
        );
      case TipoExtra.sugestao:
        return _BalaoSugestao(
          mensagem: m,
          acoesHabilitadas: ativa && !m.usada && !c.gerando,
          onUsar: () => c.usarSugestao(m),
          onEditar: () => c.editarSugestao(m),
          onGerarDeNovo: () => c.gerarDeNovo(m),
        );
    }
  }

  /// Documento aberto por cima do chat: o mesmo bloco (ou card) com as
  /// mesmas ações; a barra embaixo continua recebendo comandos.
  Widget _documento(DocumentoConversa doc) {
    final aviso = c.ultimoAvisoDo(doc);
    final requisitos = doc == DocumentoConversa.requisitos;
    final versao = requisitos
        ? (c.versaoRequisitos < 1 ? 1 : c.versaoRequisitos)
        : c.diagrama?.versao ?? 1;

    return DecoratedBox(
      decoration: const BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 4, 36, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: c.fecharDocumento,
                  style: TextButton.styleFrom(
                    foregroundColor: EstiloConversa.azulEscuro,
                    textStyle: EstiloConversa.fonte(
                        tamanho: 13, peso: FontWeight.w600),
                  ),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Voltar ao chat'),
                ),
                const Spacer(),
                Icon(requisitos ? Icons.checklist : Icons.account_tree_outlined,
                    size: 18, color: EstiloConversa.texto),
                const SizedBox(width: 6),
                Text(
                  '${requisitos ? 'Requisitos' : 'Caso de uso'} · v$versao',
                  style: EstiloConversa.fonte(peso: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(36, 0, 36, 16),
              children: [
                if (requisitos)
                  BlocoRequisitos(controlador: c, chavesCards: _chavesCards)
                else
                  CardDiagrama(controlador: c, alturaDiagrama: 340),
                if (aviso != null) _balaoExtra(aviso, ativa: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Barra lateral flutuante (à direita do modal)
// =====================================================================

/// Faz parte do modal, à direita. Fechada: só os ícones, coloridos conforme
/// a etapa (verde = concluída, laranja = atual, escuro = próximas) e os
/// documentos gerados. Ao passar o mouse (ou tocar no logo) abre mostrando
/// os nomes, e o chat encolhe para dar espaço.
class _BarraLateralModal extends StatefulWidget {
  const _BarraLateralModal({required this.conversa, required this.onEtapa});

  final ControladorConversa conversa;
  final ValueChanged<Etapa> onEtapa;

  @override
  State<_BarraLateralModal> createState() => _BarraLateralModalState();
}

class _BarraLateralModalState extends State<_BarraLateralModal> {
  bool _aberta = false;

  static IconData _icone(Etapa e) => switch (e) {
        Etapa.gerais => Icons.info,
        Etapa.requisitos => Icons.receipt_long,
        Etapa.casoUso => Icons.insert_chart_outlined,
        Etapa.equipe => Icons.groups,
        Etapa.planejamento => Icons.checklist,
      };

  @override
  Widget build(BuildContext context) {
    final c = widget.conversa;
    final docs = c.documentosGerados;

    return MouseRegion(
      onEnter: (_) => setState(() => _aberta = true),
      onExit: (_) => setState(() => _aberta = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _aberta ? 1 : 0),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          return Container(
            width:
                _larguraLateral + (_larguraLateralAberta - _larguraLateral) * t,
            padding: const EdgeInsets.only(top: 14, bottom: 14),
            // A linha divisória é desenhada por cima (não ocupa largura).
            foregroundDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                    color:
                        EstiloConversa.azulEscuro.withOpacity(0.06 + 0.06 * t)),
              ),
            ),
            child: ClipRect(
              child: Column(
                children: [
                  _Linha(
                    t: t,
                    rotulo: 'Etapas do projeto',
                    negrito: true,
                    icone: Image.asset('assets/image/tegra_logo_icon.png',
                        width: 24, height: 24),
                    onTap: () => setState(() => _aberta = !_aberta),
                  ),
                  const SizedBox(height: 6),
                  for (final e in Etapa.values) _linhaEtapa(c, e, t),
                  if (docs.isNotEmpty) const SizedBox(height: 12),
                  for (final d in docs)
                    _Linha(
                      t: t,
                      rotulo: d.doc == DocumentoConversa.requisitos
                          ? 'Requisitos'
                          : 'Caso de uso',
                      cor: c.documentoAberto == d.doc
                          ? EstiloConversa.laranja
                          : EstiloConversa.azulEscuro,
                      icone: Icon(Icons.description,
                          size: 21,
                          color: c.documentoAberto == d.doc
                              ? EstiloConversa.laranja
                              : EstiloConversa.azulEscuro),
                      dica: d.doc == DocumentoConversa.requisitos
                          ? 'Documento de requisitos'
                          : 'Documento do caso de uso',
                      onTap: () => c.documentoAberto == d.doc
                          ? c.fecharDocumento()
                          : c.abrirDocumento(d.doc),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _linhaEtapa(ControladorConversa c, Etapa e, double t) {
    final concluida = c.etapaConcluida(e);
    final atual = !concluida && c.etapaAtual == e;
    final alcancada = c.etapaAlcancada(e);
    final cor = concluida
        ? const Color(0xFF2EBD5F)
        : atual
            ? EstiloConversa.laranja
            : EstiloConversa.azulEscuro.withOpacity(alcancada ? 0.85 : 0.35);
    return _Linha(
      t: t,
      rotulo: e.rotulo,
      cor: cor,
      negrito: atual,
      icone: Icon(_icone(e), size: 21, color: cor),
      onTap: alcancada ? () => widget.onEtapa(e) : null,
    );
  }
}

/// Linha da barra lateral: rótulo (só com ela aberta) e ícone à direita.
class _Linha extends StatelessWidget {
  const _Linha({
    required this.t,
    required this.rotulo,
    required this.icone,
    this.cor = EstiloConversa.azulEscuro,
    this.negrito = false,
    this.dica,
    this.onTap,
  });

  final double t;
  final String rotulo;
  final Widget icone;
  final Color cor;
  final bool negrito;
  final String? dica;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visivel = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    final linha = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: visivel,
                child: Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Text(
                    rotulo,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: EstiloConversa.fonte(
                      tamanho: 14,
                      peso: negrito ? FontWeight.w600 : FontWeight.w500,
                      cor: cor,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _larguraLateral,
              child: Center(child: icone),
            ),
          ],
        ),
      ),
    );
    return t < 0.3
        ? Tooltip(message: dica ?? rotulo, preferBelow: false, child: linha)
        : linha;
  }
}

/// Botão à direita da barra (Salvar rascunho).
class _BotaoLateral extends StatelessWidget {
  const _BotaoLateral({
    required this.texto,
    required this.cor,
    required this.onPressed,
  });

  final String texto;
  final Color cor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final habilitado = onPressed != null;
    return Material(
      color: habilitado ? cor : cor.withOpacity(0.45),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 124,
          height: 35,
          child: Center(
            child: Text(texto,
                style: EstiloConversa.fonte(
                    tamanho: 11.5, peso: FontWeight.w600, cor: Colors.white)),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Balões
// =====================================================================

const _larguraMaximaBalao = 460.0;

/// Botão redondo de "ir para o fim da conversa".
class _BotaoDescer extends StatelessWidget {
  const _BotaoDescer({required this.visivel, required this.onTap});

  final bool visivel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visivel,
      child: AnimatedOpacity(
        opacity: visivel ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedScale(
          scale: visivel ? 1 : 0.8,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Tooltip(
            message: 'Ir para o fim da conversa',
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: Colors.black38,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: const SizedBox.square(
                  dimension: 38,
                  child: Icon(Icons.arrow_downward,
                      size: 20, color: EstiloConversa.azulEscuro),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BalaoSistema extends StatelessWidget {
  const _BalaoSistema({
    super.key,
    required this.texto,
    this.erro = false,
    this.destaque = false,
    this.acao,
  });

  final String texto;
  final bool erro;
  final bool destaque;

  /// Ação no balão (ex.: "Desfazer" no resumo de um comando de IA).
  final (String, VoidCallback)? acao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: _larguraMaximaBalao),
          padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 18),
          decoration: BoxDecoration(
            color: erro ? const Color(0xFFFBE9E7) : EstiloConversa.balaoSistema,
            borderRadius: BorderRadius.circular(16),
            border: destaque ? Border.all(color: EstiloConversa.laranja) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                texto,
                style: EstiloConversa.fonte(
                  cor: erro ? Colors.red.shade800 : EstiloConversa.texto,
                  altura: 1.2,
                ),
              ),
              if (acao != null) ...[
                const SizedBox(height: 6),
                _AcaoBalao(acao!.$1, Icons.undo, acao!.$2, principal: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BalaoUsuario extends StatelessWidget {
  const _BalaoUsuario({
    required this.texto,
    this.onEditar,
    this.pulada = false,
    this.ia = false,
  });

  final String texto;
  final VoidCallback? onEditar;
  final bool pulada;
  final bool ia;

  @override
  Widget build(BuildContext context) {
    final temLapis = onEditar != null;
    // O lápis fica 17px abaixo do balão. O espaço até o próximo balão faz
    // parte do Stack para o lápis continuar clicável (fora dos limites do
    // Stack o toque não chega).
    return Align(
      alignment: Alignment.centerRight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: temLapis ? 19 : 14),
            child: Container(
              constraints: const BoxConstraints(maxWidth: _larguraMaximaBalao),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 21),
              decoration: BoxDecoration(
                color: pulada
                    ? EstiloConversa.azulEscuro.withOpacity(0.55)
                    : EstiloConversa.azulEscuro,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ia) ...[
                    const Icon(Icons.auto_awesome,
                        size: 16, color: EstiloConversa.laranja),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      texto,
                      style: EstiloConversa.fonte(
                        cor: Colors.white,
                        altura: 1.2,
                      ).copyWith(
                        fontStyle: pulada ? FontStyle.italic : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (temLapis)
            Positioned(
              right: 13,
              bottom: -10,
              child: Tooltip(
                message: 'Editar resposta',
                child: InkResponse(
                  onTap: onEditar,
                  radius: 14,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child:
                        Icon(Icons.edit, size: 16, color: EstiloConversa.texto),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BalaoCarregando extends StatelessWidget {
  const _BalaoCarregando({this.texto = ''});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 18),
          decoration: BoxDecoration(
            color: EstiloConversa.balaoSistema,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: EstiloConversa.laranja),
              const SizedBox(width: 10),
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: EstiloConversa.laranja),
              ),
              const SizedBox(width: 10),
              Text(texto.isEmpty ? 'Gerando...' : texto,
                  style: EstiloConversa.fonte(
                      cor: EstiloConversa.textoSecundario)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalaoSugestao extends StatelessWidget {
  const _BalaoSugestao({
    required this.mensagem,
    required this.acoesHabilitadas,
    required this.onUsar,
    required this.onEditar,
    required this.onGerarDeNovo,
  });

  final MensagemExtra mensagem;
  final bool acoesHabilitadas;
  final VoidCallback onUsar;
  final VoidCallback onEditar;
  final VoidCallback onGerarDeNovo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: _larguraMaximaBalao),
          padding: const EdgeInsets.fromLTRB(21, 16, 21, 12),
          decoration: BoxDecoration(
            color: EstiloConversa.balaoSistema,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EstiloConversa.laranja.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 15, color: EstiloConversa.laranja),
                  const SizedBox(width: 6),
                  Text('Sugestão da IA',
                      style: EstiloConversa.fonte(
                          tamanho: 11,
                          peso: FontWeight.w600,
                          cor: EstiloConversa.laranja)),
                ],
              ),
              const SizedBox(height: 8),
              Text(mensagem.texto, style: EstiloConversa.fonte(altura: 1.3)),
              if (acoesHabilitadas) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 4,
                  children: [
                    _AcaoBalao('Usar', Icons.check, onUsar, principal: true),
                    _AcaoBalao('Editar', Icons.edit, onEditar),
                    _AcaoBalao('Gerar de novo', Icons.refresh, onGerarDeNovo),
                  ],
                ),
              ] else if (mensagem.usada) ...[
                const SizedBox(height: 8),
                Text('Usada',
                    style: EstiloConversa.fonte(
                        tamanho: 11, cor: EstiloConversa.textoSecundario)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AcaoBalao extends StatelessWidget {
  const _AcaoBalao(this.texto, this.icone, this.onTap,
      {this.principal = false});
  final String texto;
  final IconData icone;
  final VoidCallback onTap;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final cor = principal ? EstiloConversa.laranja : EstiloConversa.texto;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: cor,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 32),
        textStyle: EstiloConversa.fonte(tamanho: 13, peso: FontWeight.w600),
      ),
      icon: Icon(icone, size: 16),
      label: Text(texto),
    );
  }
}

class _CardResumo extends StatelessWidget {
  const _CardResumo({required this.conversa, required this.onCriar});
  final ControladorConversa conversa;
  final VoidCallback onCriar;

  @override
  Widget build(BuildContext context) {
    final c = conversa;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.fromLTRB(21, 18, 21, 16),
          decoration: BoxDecoration(
            color: EstiloConversa.balaoSistema,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resumo do projeto',
                  style: EstiloConversa.fonte(peso: FontWeight.w600)),
              const SizedBox(height: 10),
              for (var i = 0; i < c.perguntas.length; i++)
                if (c.perguntas[i].modo != ModoResposta.diagrama)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 170,
                          child: Text(c.perguntas[i].texto(c.dados),
                              style: EstiloConversa.fonte(
                                  tamanho: 12.5,
                                  cor: EstiloConversa.textoSecundario)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c.pulada(i) ? '—' : c.textoResposta(i),
                            style: EstiloConversa.fonte(tamanho: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: EstiloConversa.gradienteLaranja,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: c.enviando ? null : onCriar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white70,
                      shape: const StadiumBorder(),
                    ),
                    icon: c.enviando
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text('Criar projeto',
                        style: EstiloConversa.fonte(
                            tamanho: 14,
                            peso: FontWeight.w600,
                            cor: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Outras peças
// =====================================================================

class _BarraProgresso extends StatelessWidget {
  const _BarraProgresso({required this.valor});
  final double valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: EstiloConversa.trilhaProgresso,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: valor.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              gradient: EstiloConversa.gradienteLaranja,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
