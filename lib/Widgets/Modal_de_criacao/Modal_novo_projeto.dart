import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Steps/Edicao_Projeto_step/EdicaoProjetoStep.dart';
import 'package:fabrica_software_app/models/projeto.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Modal_step.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Steps/Planejamento_Orcamento_step/Planejamento_Orcamento_step.dart';
import 'package:fabrica_software_app/config/projeto_dto.dart';
import 'package:fabrica_software_app/providers/modal_criacao_projeto_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Abre o painel "Novo projeto" deslizando da direita.
/// Completa quando o painel fecha (cancelado ou projeto criado).
Future<void> abrirModalNovoProjeto(BuildContext context, {Projeto? projeto}) {
  final edicao = projeto != null;
  if (edicao) {
    projetoDraft.loadFromModel(projeto);
  } else {
    projetoDraft.clear();
  }
  // Guardado antes de abrir: o aviso de sucesso aparece na tela de trás,
  // depois que o painel fecha.
  final avisos = ScaffoldMessenger.of(context);

  // Abre na camada de modais: o fundo escurecido cobre a tela e o menu
  // juntos, igual a todos os outros modais.
  return CamadaModal.abrirRota<void>((_) => RawDialogRoute<void>(
    barrierDismissible: false,
    barrierLabel: edicao ? 'Editar projeto' : 'Novo projeto',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => ChangeNotifierProvider(
      create: (_) {
        final p = ModalCriacaoProjetoProvider();
        edicao ? p.iniciarEdicao() : p.iniciarCriacao();
        return p;
      },
      child: ModalNovoProjeto(avisos: avisos, edicao: edicao),
    ),
    transitionBuilder: (_, animacao, __, painel) {
      final curva =
          CurvedAnimation(parent: animacao, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(0.08, 0), end: Offset.zero)
            .animate(curva),
        child: FadeTransition(opacity: curva, child: painel),
      );
    },
  ));
}

/// Painel lateral de criação de projeto: as etapas do formulário viram abas
/// que podem ser abertas em qualquer ordem, e o projeto é criado pelo rodapé.
class ModalNovoProjeto extends StatefulWidget {
  const ModalNovoProjeto(
      {super.key, required this.avisos, this.edicao = false});

  /// ScaffoldMessenger da tela que abriu o painel.
  final ScaffoldMessengerState avisos;

  /// Editando um projeto existente (só as informações gerais).
  final bool edicao;

  @override
  State<ModalNovoProjeto> createState() => _ModalNovoProjetoState();
}

class _ModalNovoProjetoState extends State<ModalNovoProjeto> {
  static const _borda = Color(0x1F0F1030);
  static const _fundoAbas = Color(0xFFEEF0F6);

  int _aba = 0;

  /// Distância do topo do modal até a barra de abas (cabeçalho + divisória
  /// + espaço), para a aba do assistente ficar na mesma linha.
  static const _topoAbas = 113.0;

  /// Sem espaço ao lado do modal, o assistente abre pelo cabeçalho.
  bool _assistenteNoCabecalho = false;

  /// Abas já abertas. Só elas são montadas (e ficam montadas, para não
  /// perder o que foi preenchido ao trocar de aba).
  final Set<int> _abertas = {0};
  bool _criando = false;

  // Mensagens das etapas aparecem no canto superior direito do painel.
  final _avisosPainel = GlobalKey<AvisosIdvState>();

  /// Assistente de IA da aba aberta, mostrado num painel filho ao lado.
  final _assistente = AssistenteIdv();

  @override
  void initState() {
    super.initState();
    _assistente.addListener(_aoMudarAssistente);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _assistente.ativar(_etapas[_aba].tabName);
    });
  }

  void _aoMudarAssistente() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _assistente.removeListener(_aoMudarAssistente);
    _assistente.dispose();
    super.dispose();
  }

  List<ModalStep> get _etapas =>
      context.read<ModalCriacaoProjetoProvider>().etapas;

  void _irPara(int indice) {
    if (indice == _aba) return;
    _etapas[_aba].salvar();
    // O assistente pertence à aba: troca junto com ela.
    _assistente.ativar(_etapas[indice].tabName);
    setState(() {
      _aba = indice;
      _abertas.add(indice);
    });
  }

  void _cancelar() {
    projetoDraft.clear();
    Navigator.pop(context);
  }

  Future<void> _salvarEdicao() async {
    final etapa = _etapas.first as EdicaoProjetoStep;
    if (!etapa.validar()) return;
    setState(() => _criando = true);
    final salvo = await etapa.concluirEdicao(context);
    if (!mounted) return;
    setState(() => _criando = false);
    if (salvo) {
      projetoDraft.clear();
      Navigator.pop(context);
      avisarApp('Projeto atualizado!', tipo: TipoAviso.sucesso);
    }
  }

  Future<void> _criar() async {
    if (widget.edicao) return _salvarEdicao();
    final etapas = _etapas;
    for (var i = 0; i < etapas.length; i++) {
      if (_abertas.contains(i)) etapas[i].salvar();
    }

    for (var i = 0; i < etapas.length; i++) {
      final etapa = etapas[i];
      if (!_abertas.contains(i)) {
        if (!etapa.obrigatoria) continue;
        _irPara(i);
        _avisosPainel.currentState?.mostrar(
            'Preencha a aba "${etapa.tabName}" para continuar.',
            tipo: TipoAviso.info);
        return;
      }
      if (!etapa.validar()) {
        _irPara(i);
        return;
      }
    }

    final finalizacao = etapas.whereType<PlanejamentoOrcamentoStep>().first;
    setState(() => _criando = true);
    final criado = await finalizacao.concluir();
    if (!mounted) return;
    setState(() => _criando = false);

    if (criado) {
      Navigator.pop(context);
      avisarApp('Projeto criado!', tipo: TipoAviso.sucesso);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.of(context).size;
    final largura = tela.width < 760
        ? tela.width - 32
        : (tela.width * 0.58).clamp(720.0, 1180.0);
    final tema = temaIdv(Theme.of(context));

    final painel = SizedBox(
      width: largura,
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(StyleProjetos.sidebarAbertaRaio),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: tema,
          child: AvisosIdv(
            key: _avisosPainel,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  _cabecalho(),
                  const Divider(height: 1, color: _borda),
                  // Com uma aba só (edição), a barra de abas não aparece.
                  if (_etapas.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                      child: _abas(),
                    )
                  else
                    const SizedBox(height: 16),
                  Expanded(
                    child: EscopoAssistenteIdv(
                      assistente: _assistente,
                      child: _corpo(),
                    ),
                  ),
                  const Divider(height: 1, color: _borda),
                  _rodape(),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Espaço livre à esquerda do modal (a parte da tela sem informação).
    final livre = tela.width - largura - 32;
    final aoLado = livre >= 360;
    _assistenteNoCabecalho = !aoLado;
    final larguraFilho = aoLado
        ? (livre - 12).clamp(340.0, 420.0)
        : (largura - 24).clamp(0.0, 380.0);

    final filho = _assistente.aberto
        ? Theme(
            data: tema,
            child: SizedBox(
              width: larguraFilho,
              child: ChatIAPanelFilho(conteudo: _assistente.construir(context)),
            ),
          )
        : null;
    final aba = _assistente.disponivel && !_assistente.aberto
        ? AbaAssistenteIdv(aoAbrir: _assistente.abrir)
        : null;

    if (aoLado) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (w, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0.06, 0), end: Offset.zero)
                            .animate(anim),
                    child: w,
                  ),
                ),
                child: filho != null
                    ? Padding(
                        key: const ValueKey('assistente'),
                        padding: const EdgeInsets.only(right: 12),
                        child: filho,
                      )
                    : aba != null
                        ? Padding(
                            key: const ValueKey('aba'),
                            padding: const EdgeInsets.only(
                                top: _topoAbas, right: 12),
                            child: Align(
                                alignment: Alignment.topRight, child: aba),
                          )
                        : const SizedBox.shrink(key: ValueKey('nada')),
              ),
              painel,
            ],
          ),
        ),
      );
    }

    // Tela estreita: o assistente abre por cima da parte esquerda do modal.
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            painel,
            if (filho != null)
              Positioned(
                left: 12,
                top: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x330F1030),
                          blurRadius: 24,
                          offset: Offset(0, 8)),
                    ],
                  ),
                  child: filho,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 16, 18),
      child: Row(
        children: [
          Text(
            widget.edicao ? 'Editar projeto' : 'Novo projeto',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: StyleProjetos.texto,
              letterSpacing: -0.3,
            ),
          ),
          if (_etapas[_aba].ajuda != null) ...[
            const SizedBox(width: 10),
            AjudaIdv(
              // Chave por aba: o balão troca de texto junto com a aba.
              key: ValueKey(_aba),
              texto: _etapas[_aba].ajuda!,
            ),
          ],
          const Spacer(),
          if (_assistenteNoCabecalho &&
              _assistente.disponivel &&
              !_assistente.aberto)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _assistente.abrir,
                icon: const Icon(FontAwesomeIcons.wandMagicSparkles,
                    size: 14, color: StyleProjetos.laranja),
                label: Text('Assistente IA',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: StyleProjetos.azulEscuro)),
              ),
            ),
          IconButton(
            tooltip: 'Fechar',
            onPressed: _criando ? null : _cancelar,
            icon: const Icon(Icons.close, color: StyleProjetos.textoSecundario),
          ),
        ],
      ),
    );
  }

  Widget _abas() {
    final etapas = _etapas;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _fundoAbas,
        borderRadius: BorderRadius.circular(14),
      ),
      // Abas dividem a largura toda; o texto nunca é cortado (em janelas
      // estreitas ele só diminui).
      child: Row(
        children: [
          for (var i = 0; i < etapas.length; i++)
            Expanded(
              child: _Aba(
                rotulo: etapas[i].tabName,
                selecionada: i == _aba,
                onTap: _criando ? null : () => _irPara(i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _corpo() {
    final etapas = _etapas;
    return IndexedStack(
      index: _aba,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < etapas.length; i++)
          if (!_abertas.contains(i))
            const SizedBox.shrink()
          else if (etapas[i].temPainelProprio)
            etapas[i].buildBody(context)
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
              child: etapas[i].buildBody(context),
            ),
      ],
    );
  }

  Widget _rodape() {
    final pilula = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleProjetos.botaoRaio));
    final textoBotao =
        GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _criando ? null : _cancelar,
            style: OutlinedButton.styleFrom(
              foregroundColor: StyleProjetos.texto,
              side: const BorderSide(color: Color(0x330F1030)),
              shape: pilula,
              minimumSize: const Size(120, 46),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              textStyle: textoBotao,
            ),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: StyleProjetos.gradienteLaranja,
              borderRadius: BorderRadius.circular(StyleProjetos.botaoRaio),
            ),
            child: ElevatedButton(
              onPressed: _criando ? null : _criar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: pilula,
                minimumSize: const Size(160, 46),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                textStyle: textoBotao,
              ),
              child: _criando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.edicao ? 'Salvar alterações' : 'Criar projeto'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({
    required this.rotulo,
    required this.selecionada,
    required this.onTap,
  });

  final String rotulo;
  final bool selecionada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selecionada ? StyleProjetos.azulEscuro : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              rotulo,
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: selecionada ? FontWeight.w600 : FontWeight.w500,
                color:
                    selecionada ? Colors.white : StyleProjetos.textoSecundario,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Moldura do painel filho do assistente (mesmo raio do modal).
class ChatIAPanelFilho extends StatelessWidget {
  const ChatIAPanelFilho({super.key, required this.conteudo});
  final Widget conteudo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(StyleProjetos.sidebarAbertaRaio),
      clipBehavior: Clip.antiAlias,
      child: conteudo,
    );
  }
}
