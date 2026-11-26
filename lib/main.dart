import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/providers/recursos_provider.dart';
import 'package:fabrica_software_app/providers/tecnologias_provider.dart';
import 'package:fabrica_software_app/screens/Cadastro/Cadastro_screen.dart';
import 'package:fabrica_software_app/screens/RecuperarSenha/recuperar_senha_screen.dart';
import 'package:fabrica_software_app/screens/Account/Account.dart';
import 'package:fabrica_software_app/screens/Clientes/Clientes.dart';
import 'package:fabrica_software_app/screens/Equipe/Gerenciar_Equipes_Screen.dart';
import 'package:fabrica_software_app/screens/Recursos/Recursos.dart';
import 'package:fabrica_software_app/screens/Relatorio/Relatorio_Screen.dart';
import 'package:fabrica_software_app/screens/Tecnologias/Tecnologias.dart';
import 'package:fabrica_software_app/screens/Usuarios/usuarios.dart';
import 'package:fabrica_software_app/services/base_api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/usuarios_provider.dart';
import 'providers/projetos_provider.dart';
import 'providers/clientes_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/Login/login_screen.dart';
import 'screens/Gerenciar_Projetos/Gerenciar_projetos.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
void main() async { 
  
  // --- MUDANÇA 2: Garanta que o Flutter está pronto
  WidgetsFlutterBinding.ensureInitialized(); 

  // --- MUDANÇA 3: Inicialize o Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Token recusado pelo servidor: sai da conta e volta ao login.
  BaseApiService.aoSessaoExpirada = tratarSessaoExpirada;

  // Seu código original
  runApp(
    MultiProvider(
      providers:[
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UsuariosProvider()),
        ChangeNotifierProvider(create: (_) => ProjetosProvider()),
        ChangeNotifierProvider(create: (_) { return RecursosProvider();}),
        ChangeNotifierProvider(create: (_) { return ClientesProvider();}),
        ChangeNotifierProvider(create: (_) { return TecnologiasProvider();}),
      ],  
      child: MyApp(),
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observadorRotas],
        // Menu lateral em todas as telas, exceto login e cadastro.
        builder: (context, child) => LayoutPrincipal(child: child),
        initialRoute: '/',
        // onGenerateRoute em vez de routes: toda tela passa pela guarda
        // de login/nível (GuardaRota).
        onGenerateRoute: (settings) {
          final tela = _telas[settings.name];
          if (tela == null) return null;
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => GuardaRota(rota: settings.name!, tela: tela),
          );
        },
        title: 'Fábrica de Software',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          // Troca de tela discreta e igual em todas as plataformas.
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: TransicaoSuave(),
            TargetPlatform.iOS: TransicaoSuave(),
            TargetPlatform.windows: TransicaoSuave(),
            TargetPlatform.macOS: TransicaoSuave(),
            TargetPlatform.linux: TransicaoSuave(),
            TargetPlatform.fuchsia: TransicaoSuave(),
          }),
        ),
      );
  }
}

/// Telas do app por rota.
final Map<String, WidgetBuilder> _telas = {
  RotasApp.login: (_) => const Loginscreen(),
  RotasApp.cadastro: (_) => const CadastroScreen(),
  RotasApp.recuperarSenha: (_) => const RecuperarSenhaScreen(),
  RotasApp.projetos: (_) => const GerenciarProjetos(),
  RotasApp.perfil: (_) => const Account(),
  RotasApp.clientes: (_) => const Clientes(),
  RotasApp.recursos: (_) => const Recursos(),
  RotasApp.tecnologias: (_) => const Tecnologias(),
  RotasApp.usuarios: (_) => const Usuarios(),
  RotasApp.equipes: (_) => const GerenciarEquipesScreen(),
  RotasApp.relatorios: (_) => const RelatoriosScreen(),
};

/// Guarda de rota: sem login, só login/cadastro/recuperar senha; logado,
/// o login vai para Projetos; Gestão de usuários só para ADMINISTRADOR e
/// MASTER. Enquanto o AuthProvider lê a sessão, mostra um indicador.
class GuardaRota extends StatelessWidget {
  const GuardaRota({super.key, required this.rota, required this.tela});

  final String rota;
  final WidgetBuilder tela;

  /// Para onde mandar, ou null quando pode ficar em [rota].
  static String? destino(String rota, bool logado, String? nivel) {
    final publica = RotasApp.semMenu.contains(rota);
    if (!logado) return publica ? null : RotasApp.login;
    if (rota == RotasApp.login) return RotasApp.projetos;
    if (!RotasApp.permitida(rota, nivel)) return RotasApp.projetos;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // select: só reconstrói quando o login ou o nível mudam.
    final (logado, nivel) = context.select<AuthProvider, (bool?, String?)>(
        (a) => (a.isAuthenticated, a.userNivel));
    const carregando = Center(child: CircularProgressIndicator());
    if (logado == null) return carregando;

    final ir = destino(rota, logado, nivel);
    if (ir == null) return tela(context);

    // Navega depois do frame (não dá para navegar no meio do build). Se a
    // tela já saiu (ex.: o login já abriu Projetos), não faz nada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      navigatorKey.currentState?.pushNamedAndRemoveUntil(ir, (_) => false);
    });
    // Tela pública (login) pode aparecer durante a troca; tela protegida
    // nunca é montada sem permissão.
    return RotasApp.semMenu.contains(rota) ? tela(context) : carregando;
  }
}

/// Troca de tela: a nova aparece enquanto a anterior some (esmaecer cruzado
/// rápido). As telas não têm fundo próprio, então a anterior precisa sumir
/// junto, senão as duas ficariam sobrepostas no meio da troca.
class TransicaoSuave extends PageTransitionsBuilder {
  const TransicaoSuave();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Login, cadastro e recuperar senha têm o mesmo fundo: a nova entra
    // devagar por cima e a anterior só some no fim, então o fundo fica
    // parado e só o card troca (sem o escurecido no meio).
    final entradaLogin = RotasApp.semMenu.contains(route.settings.name);
    final entrada = CurvedAnimation(
        parent: animation,
        curve: entradaLogin
            ? Curves.easeInOutCubic
            : const Interval(0.2, 1, curve: Curves.easeOut));
    final saida = CurvedAnimation(
        parent: secondaryAnimation,
        curve: entradaLogin
            ? const Interval(0.7, 1, curve: Curves.easeOut)
            : const Interval(0, 0.6, curve: Curves.easeOut));
    return FadeTransition(
      opacity: entrada,
      child: FadeTransition(opacity: ReverseAnimation(saida), child: child),
    );
  }
}
