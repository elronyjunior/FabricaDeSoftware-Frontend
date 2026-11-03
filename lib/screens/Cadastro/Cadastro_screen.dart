import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/screens/Login/Components/auth_components.dart';
import 'package:fabrica_software_app/screens/Login/Styles/style_login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _nomeController = TextEditingController();
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
        Navigator.pushNamedAndRemoveUntil(
            context, '/Gerenciar_Projetos', (_) => false);
      } else {
        _mostrarErro(auth.error ?? mensagemFalha);
      }
    } catch (e) {
      _mostrarErro('$mensagemFalha: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cadastrar() {
    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
      _mostrarErro('Preencha nome, email e senha.');
      return;
    }
    if (!email.contains('@')) {
      _mostrarErro('Digite um email válido.');
      return;
    }
    if (senha.length < 6) {
      _mostrarErro('A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    _autenticar(
      (auth) => auth.register(
        nome: nome,
        email: email,
        senha: senha,
        telefone: '', // o layout novo não tem campo de telefone
      ),
      'Não foi possível criar a conta',
    );
  }

  void _entrarComGoogle() {
    _autenticar((auth) => auth.loginWithGoogle(), 'Falha no login com Google');
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    avisar(context, mensagem, tipo: TipoAviso.info);
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
            Text('Crie sua conta',
                textAlign: TextAlign.center, style: StyleLogin.titulo),
            const SizedBox(height: 23),
            CampoVidro(
              controller: _nomeController,
              hint: 'Nome',
              icone: Icons.person,
              teclado: TextInputType.name,
              acao: TextInputAction.next,
              autofill: const [AutofillHints.name],
            ),
            const SizedBox(height: 27),
            CampoVidro(
              controller: _emailController,
              hint: 'Email',
              icone: Icons.email,
              teclado: TextInputType.emailAddress,
              acao: TextInputAction.next,
              autofill: const [AutofillHints.email],
            ),
            const SizedBox(height: 27),
            CampoVidro(
              controller: _senhaController,
              hint: 'Senha',
              icone: Icons.lock,
              oculto: true,
              acao: TextInputAction.done,
              autofill: const [AutofillHints.newPassword],
              aoEnviar: (_) => _isLoading ? null : _cadastrar(),
            ),
            const SizedBox(height: 18),
            BotaoLaranja(
              texto: 'Cadastrar',
              carregando: _isLoading,
              onPressed: _isLoading ? null : _cadastrar,
            ),
            const SizedBox(height: 9),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Já tem uma conta? Faça o ', style: StyleLogin.rodape),
                LinkSublinhado(
                  texto: 'login',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const DivisorOu(),
            const SizedBox(height: 25),
            BotaoGoogle(onPressed: _isLoading ? null : _entrarComGoogle),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }
}