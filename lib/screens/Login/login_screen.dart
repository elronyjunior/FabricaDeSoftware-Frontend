import 'package:fabrica_software_app/screens/Login/Components/auth_components.dart';
import 'package:fabrica_software_app/screens/Login/Styles/style_login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../Gerenciar_Projetos/Gerenciar_projetos.dart';

class Loginscreen extends StatefulWidget {
  const Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends State<Loginscreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _isLoading = false;

  // ---------------- Lógica ----------------

  Future<void> _autenticar(
    Future<bool> Function(AuthProvider auth) acao,
    String mensagemFalha,
  ) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final success = await acao(auth);
      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GerenciarProjetos()),
        );
      } else {
        _mostrarErro(auth.error ?? mensagemFalha);
      }
    } catch (e) {
      _mostrarErro('$mensagemFalha: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _entrarComEmail() {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    if (email.isEmpty || senha.isEmpty) {
      _mostrarErro('Preencha email e senha');
      return;
    }
    _autenticar((auth) => auth.login(email, senha), 'Falha no login');
  }

  void _entrarComGoogle() {
    _autenticar((auth) => auth.loginWithGoogle(), 'Falha no login com Google');
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoTegra(),
            const SizedBox(height: 4),
            Text('Entre em sua conta',
                textAlign: TextAlign.center, style: StyleLogin.titulo),
            const SizedBox(height: 62),
            CampoVidro(
              controller: _emailController,
              hint: 'Email',
              icone: Icons.email,
              teclado: TextInputType.emailAddress,
              acao: TextInputAction.next,
              autofill: const [AutofillHints.email],
            ),
            const SizedBox(height: 39),
            CampoVidro(
              controller: _senhaController,
              hint: 'Senha',
              icone: Icons.lock,
              oculto: true,
              acao: TextInputAction.done,
              autofill: const [AutofillHints.password],
              aoEnviar: (_) => _isLoading ? null : _entrarComEmail(),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: StyleLogin.campoLargura),
              child: Align(
                alignment: Alignment.centerRight,
                child: LinkSublinhado(
                  texto: 'Esqueci a senha',
                  onTap: () => Navigator.pushNamed(context, '/Account'),
                ),
              ),
            ),
            const SizedBox(height: 30),
            BotaoLaranja(
              texto: 'Entrar',
              carregando: _isLoading,
              onPressed: _isLoading ? null : _entrarComEmail,
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Não tem uma conta? ', style: StyleLogin.rodape),
                LinkSublinhado(
                  texto: 'Cadastre-se',
                  onTap: () => Navigator.pushNamed(context, '/Cadastro'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const DivisorOu(),
            const SizedBox(height: 24),
            BotaoGoogle(onPressed: _isLoading ? null : _entrarComGoogle),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }
}