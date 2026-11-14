import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'dart:async';

import 'package:fabrica_software_app/providers/auth_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/components/sidebar_flutuante.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Nomes das rotas do app (os mesmos do `routes:` do main.dart).
class RotasApp {
  RotasApp._();

  static const login = '/';
  static const cadastro = '/Cadastro';
  static const recuperarSenha = '/RecuperarSenha';
  static const projetos = '/Gerenciar_Projetos';
  static const equipes = '/Equipes';
  static const relatorios = '/Relatorios';
  static const usuarios = '/Usuarios';
  static const clientes = '/Clientes';
  static const tecnologias = '/Tecnologias';
  static const perfil = '/Account';

  /// Destino de cada item do menu, na mesma ordem de [SidebarFlutuante.itens].
  static const menu = [
    projetos,
    equipes,
    relatorios,
    usuarios,
    clientes,
    tecnologias,
  ];

  /// Telas que não exibem o menu lateral.
  static const semMenu = {login, cadastro, recuperarSenha};
}

/// Chave do Navigator principal: permite navegar a partir do menu,
/// que fica fora do Navigator.
final navigatorKey = GlobalKey<NavigatorState>();

/// Acompanha a pilha de telas para saber qual item do menu destacar
/// e se o menu deve aparecer.
final observadorRotas = ObservadorRotas();

class ObservadorRotas extends NavigatorObserver with ChangeNotifier {
  final List<Route<dynamic>> _paginas = [];
  int _popups = 0;
  bool _avisoAgendado = false;

  String? get rotaAtual =>
      _paginas.isEmpty ? null : _paginas.last.settings.name;

  bool get mostrarMenu =>
      _paginas.isNotEmpty && !RotasApp.semMenu.contains(rotaAtual);

  /// Há um diálogo/modal aberto por cima da tela.
  bool get temPopup => _popups > 0;

  /// Item do menu da tela atual. Telas abertas por dentro de outra
  /// (ex.: detalhes do projeto) herdam o item da tela de origem.
  int get indiceAtivo {
    for (final rota in _paginas.reversed) {
      final i = RotasApp.menu.indexOf(rota.settings.name ?? '');
      if (i >= 0) return i;
    }
    return -1;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _paginas.add(route);
    } else if (_escurece(route)) {
      _popups++;
    }
    _avisar();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remover(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remover(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _paginas.indexOf(oldRoute);
    if (i >= 0 && newRoute is PageRoute) {
      _paginas[i] = newRoute;
    } else {
      if (oldRoute != null) _remover(oldRoute);
      if (newRoute is PageRoute) _paginas.add(newRoute);
    }
    _avisar();
  }

  void _remover(Route<dynamic> route) {
    if (route is PopupRoute) {
      if (_escurece(route) && _popups > 0) _popups--;
    } else {
      _paginas.remove(route);
    }
    _avisar();
  }

  /// Pop-ups com fundo escurecido (os menus e listas suspensas não têm).
  static bool _escurece(Route<dynamic> route) =>
      route is PopupRoute && (route.barrierColor?.alpha ?? 0) > 0;

  /// O Navigator avisa no meio do build; a atualização do menu
  /// fica para depois do frame.
  void _avisar() {
    if (_avisoAgendado) return;
    _avisoAgendado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _avisoAgendado = false;
      notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

// =====================================================================
// Ações do menu
// =====================================================================

/// Abre uma tela do menu, limpando a pilha (o menu é a navegação principal).
void navegarPara(String rota) {
  final navegador = navigatorKey.currentState;
  if (navegador == null || observadorRotas.rotaAtual == rota) return;
  navegador.pushNamedAndRemoveUntil(rota, (_) => false);
}

Future<void> sairDaConta(BuildContext context) async {
  await context.read<AuthProvider>().logout();
  navigatorKey.currentState
      ?.pushNamedAndRemoveUntil(RotasApp.login, (_) => false);
}

/// O menu lateral já ligado às rotas do app.
class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key, this.sempreAberta = false, this.aoNavegar});

  final bool sempreAberta;

  /// Chamado antes de navegar (ex.: fechar o Drawer no celular).
  final VoidCallback? aoNavegar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: observadorRotas,
      builder: (context, _) => SidebarFlutuante(
        sempreAberta: sempreAberta,
        indiceAtivo: observadorRotas.indiceAtivo,
        onSelecionar: (i) {
          aoNavegar?.call();
          navegarPara(RotasApp.menu[i]);
        },
        onAlternarTema: () {/* TODO: alternar tema */},
        onPerfil: () {
          aoNavegar?.call();
          navegarPara(RotasApp.perfil);
        },
        onSair: () {
          aoNavegar?.call();
          sairDaConta(context);
        },
      ),
    );
  }
}

// =====================================================================
// Camada de modal em tela cheia
// =====================================================================

/// Modal que cobre a janela inteira, inclusive o menu lateral fixo (que fica
/// fora do Navigator). Um único fundo escurecido para tudo: tela, menu e a
/// sombra do menu escurecem juntos, na mesma animação de entrada e saída.
///
/// Todos os diálogos do app abrem aqui ([mostrarDialogo]): se abrissem no
/// Navigator principal, o escurecido ficaria só à direita do menu e o menu
/// teria que ser escurecido à parte.
class CamadaModal {
  CamadaModal._();

  static final conteudo = ValueNotifier<Widget?>(null);
  static Completer<void>? _aoFechar;

  /// Muda a cada abertura: cada modal ganha uma camada (e um Navigator) nova.
  static int _id = 0;

  /// Pedido de fechar: a camada faz a animação de saída e depois some.
  static final _fechando = ValueNotifier<bool>(false);

  /// Navigator da camada (os diálogos abertos por [mostrarDialogo]).
  static final navegador = GlobalKey<NavigatorState>();

  static bool get aberta => conteudo.value != null;

  /// Mostra [modal]; completa quando [fechar] for chamado.
  static Future<void> abrir(Widget modal) {
    _aoFechar?.complete();
    final completer = Completer<void>();
    _aoFechar = completer;
    _id++;
    _fechando.value = false;
    conteudo.value = modal;
    return completer.future;
  }

  /// Abre a camada e empilha a rota criada por [criar] no Navigator dela.
  /// A camada fecha (com a animação de saída) quando a rota sai.
  static Future<T?> abrirRota<T>(
      Route<T> Function(BuildContext context) criar) async {
    abrir(const SizedBox.expand());
    final id = _id;
    await WidgetsBinding.instance.endOfFrame;
    final nav = navegador.currentState;
    if (nav == null || id != _id) return null;
    final resultado = await nav.push<T>(criar(nav.context));
    if (id == _id) fechar();
    return resultado;
  }

  static void fechar() {
    if (conteudo.value == null) return;
    _fechando.value = true;
    final completer = _aoFechar;
    _aoFechar = null;
    completer?.complete();
  }

  /// Chamado pela camada no fim da animação de saída.
  static void _remover(int id) {
    if (id != _id) return;
    _fechando.value = false;
    conteudo.value = null;
  }
}

/// Mesmo uso do `showDialog`, mas o diálogo abre na [CamadaModal], com o
/// mesmo fundo de todos os modais. De dentro de um modal, abre por cima dele.
Future<T?> mostrarDialogo<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  final camada = CamadaModal.navegador.currentState;
  final dentroDaCamada = camada != null &&
      Navigator.maybeOf(context, rootNavigator: true) == camada;
  if (dentroDaCamada) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }
  final temas = InheritedTheme.capture(from: context, to: null);
  return CamadaModal.abrirRota<T>(
    (ctx) => DialogRoute<T>(
      context: ctx,
      builder: builder,
      themes: temas,
      barrierColor: Colors.transparent,
      barrierDismissible: barrierDismissible,
    ),
  );
}

class _CamadaModalView extends StatefulWidget {
  const _CamadaModalView({super.key, required this.id, required this.child});
  final int id;
  final Widget child;

  @override
  State<_CamadaModalView> createState() => _CamadaModalViewState();
}

class _CamadaModalViewState extends State<_CamadaModalView>
    with SingleTickerProviderStateMixin {
  /// Fundo por trás de todos os modais (também cobre o menu lateral).
  static const _barreira = Colors.black54;

  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
  )..forward();

  @override
  void initState() {
    super.initState();
    CamadaModal._fechando.addListener(_aoPedirFechar);
  }

  void _aoPedirFechar() {
    if (!CamadaModal._fechando.value) return;
    _entrada.reverse().whenComplete(() => CamadaModal._remover(widget.id));
  }

  @override
  void dispose() {
    CamadaModal._fechando.removeListener(_aoPedirFechar);
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entrada,
      builder: (context, filho) {
        final t = Curves.easeOutCubic.transform(_entrada.value);
        return IgnorePointer(
          // Saindo: os toques já passam para a tela de trás.
          ignoring: _entrada.status == AnimationStatus.reverse,
          child: Stack(
            children: [
              // Fundo: absorve os toques e escurece a janela toda.
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: _barreira.withOpacity(_barreira.opacity * t),
                  ),
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: t,
                  child:
                      Transform.scale(scale: 0.97 + 0.03 * t, child: filho),
                ),
              ),
            ],
          ),
        );
      },
      // Navigator próprio: os diálogos e os pop-ups abertos de dentro do
      // modal (confirmar, calendário, tela cheia) aparecem por cima dele.
      // HeroControllerScope.none: sem isso este Navigator dividiria o
      // HeroController do app com o Navigator principal, que ficava travado
      // depois de fechar o modal (cliques sem abrir telas nem diálogos).
      child: HeroControllerScope.none(
        child: Navigator(
          key: CamadaModal.navegador,
          onGenerateRoute: (_) => PageRouteBuilder<void>(
            opaque: false,
            pageBuilder: (_, __, ___) => widget.child,
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Layout global (MaterialApp.builder)
// =====================================================================

/// Envolve o Navigator do app e mostra o menu lateral fixo à esquerda
/// em todas as telas, exceto login e cadastro.
///
/// Em telas estreitas o menu não fica fixo: cada tela o abre pelo
/// Drawer (`BarraLateral.drawer(context)`).
class LayoutPrincipal extends StatelessWidget {
  const LayoutPrincipal({super.key, required this.child});

  /// O Navigator criado pelo MaterialApp.
  final Widget? child;

  /// Largura a partir da qual o menu fica fixo na tela.
  static const double larguraDesktop = 900;

  /// Largura de referência do Figma.
  static const double larguraBase = 1280;

  /// Espaço reservado para o menu fechado, na escala do Figma
  /// (26 de margem + a largura do menu fechado).
  static const double recuoConteudo = 26 + StyleProjetos.sidebarLargura;

  /// Altura mínima (na escala do Figma) para o menu caber sem cortar.
  static const double _alturaMinimaMenu = 640;

  static double escala(double largura) =>
      (largura / larguraBase).clamp(0.75, 2.0).toDouble();

  /// `true` quando o menu está fixo na tela (e o Drawer não é necessário).
  static bool menuFixo(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EscopoMenu>()?.fixo ?? false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([observadorRotas, CamadaModal.conteudo]),
      builder: (context, _) {
        final modal = CamadaModal.conteudo.value;
        final midia = MediaQuery.of(context);
        final tela = midia.size;
        final fixo =
            observadorRotas.mostrarMenu && tela.width >= larguraDesktop;
        final e = escala(tela.width);
        final dpr = midia.devicePixelRatio;
        final recuo =
            fixo ? (recuoConteudo * e * dpr).roundToDouble() / dpr : 0.0;

        // A estrutura da árvore é sempre a mesma, para o Navigator
        // nunca ser recriado ao mostrar/esconder o menu.
        // AvisosIdv: mensagens do app no canto superior direito, por cima de
        // todas as telas e diálogos.
        return AvisosIdv(
          key: AvisosIdv.global,
          child: DecoratedBox(
          decoration:
              const BoxDecoration(gradient: StyleProjetos.gradienteFundo),
          child: Stack(
            children: [
              Positioned.fill(
                left: recuo,
                child: MediaQuery(
                  data: midia.copyWith(
                    size: Size(tela.width - recuo, tela.height),
                  ),
                  child: _EscopoMenu(
                    fixo: fixo,
                    // Com o modal aberto, o teclado não alcança a tela de trás.
                    child: ExcludeFocus(
                      excluding: modal != null,
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              if (fixo)
                Positioned(
                  left: 26 * e,
                  top: 23 * e,
                  child: _menuEscalado(
                    tela.height - 46 * e,
                    e,
                    bloqueado: observadorRotas.temPopup || modal != null,
                  ),
                ),
              // Com um diálogo aberto, o menu também fica escurecido, com a
              // mesma cor da barreira dos diálogos (sem desfoque, para não
              // criar uma emenda entre o menu e a tela).
              if (fixo && modal == null)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: recuo,
                  child: IgnorePointer(
                    ignoring: !observadorRotas.temPopup,
                    child: AnimatedOpacity(
                      opacity: observadorRotas.temPopup ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const ColoredBox(color: Colors.black54),
                    ),
                  ),
                ),
              // Com chave: o modal não é recriado (nem perde a conversa)
              // quando o menu fixo aparece ou some ao redimensionar a janela.
              if (modal != null)
                Positioned.fill(
                  key: const ValueKey('camada-modal'),
                  child: _CamadaModalView(
                    key: ValueKey(CamadaModal._id),
                    id: CamadaModal._id,
                    child: modal,
                  ),
                ),
            ],
          ),
        ),
        );
      },
    );
  }

  /// Desenha o menu na escala do Figma, como na tela de Projetos.
  /// Em janelas baixas, reduz um pouco mais para os itens caberem.
  ///
  /// O IgnorePointer fica dentro do Transform: só o Transform considera
  /// a área ampliada ao detectar toques.
  Widget _menuEscalado(double alturaDisponivel, double e,
      {required bool bloqueado}) {
    var escalaMenu = e;
    var alturaDesign = alturaDisponivel / e;
    if (alturaDesign < _alturaMinimaMenu) {
      alturaDesign = _alturaMinimaMenu;
      escalaMenu = alturaDisponivel / _alturaMinimaMenu;
    }

    return Transform.scale(
      scale: escalaMenu,
      alignment: Alignment.topLeft,
      child: IgnorePointer(
        // Com um diálogo aberto, o menu não responde (nem ao mouse, nem ao
        // teclado).
        ignoring: bloqueado,
        child: ExcludeFocus(
          excluding: bloqueado,
          child: SizedBox(
            height: alturaDesign,
            child: const MenuLateral(),
          ),
        ),
      ),
    );
  }
}

class _EscopoMenu extends InheritedWidget {
  const _EscopoMenu({required this.fixo, required super.child});

  final bool fixo;

  @override
  bool updateShouldNotify(_EscopoMenu oldWidget) => fixo != oldWidget.fixo;
}
