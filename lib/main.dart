// ignore: unused_import
import 'package:fabrica_software_app/models/recurso.dart';
import 'package:fabrica_software_app/models/teste.dart';
import 'package:fabrica_software_app/models/usuario.dart';
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
import 'package:fabrica_software_app/screens/Tests/Teste_screen.dart';
import 'package:fabrica_software_app/screens/Usuarios/usuarios.dart';
// ignore: unused_import
import 'package:fabrica_software_app/services/requisito_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/usuarios_provider.dart';
import 'providers/projetos_provider.dart';
import 'providers/clientes_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/Api_teste/api_test_screen.dart';
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
        routes: {
          '/':(context){return const Loginscreen();},
          '/Cadastro':(context){return const CadastroScreen();},
          RotasApp.recuperarSenha: (context) => const RecuperarSenhaScreen(),
          '/ApiTest':(context){return const ApiTestScreen();},
          '/Gerenciar_Projetos':(context){return const GerenciarProjetos();},
          '/Account':(context){return const Account();},
          '/Clientes':(context){return const Clientes();},
          '/Recursos':(context){return const Recursos();},
          '/Tecnologias':(context){return const Tecnologias();},
          '/Usuarios':(context){return const Usuarios();},
          '/Equipes':(context){return const GerenciarEquipesScreen();},
          '/Relatorios':(context){return const RelatoriosScreen();}
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
