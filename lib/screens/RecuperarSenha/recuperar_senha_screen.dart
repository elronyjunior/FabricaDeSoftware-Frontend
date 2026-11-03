import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/screens/Login/Components/auth_components.dart';
import 'package:fabrica_software_app/screens/Login/Styles/style_login.dart';
import 'package:flutter/material.dart';

/// "Esqueci a senha": fica fora do painel (sem menu), no mesmo visual do
/// login e do cadastro.
///
/// O back-end ainda não tem rota de recuperação de senha (só login,
/// cadastro, refresh e login com Google), então o envio só avisa que a
/// recuperação por e-mail ainda não está disponível.
class RecuperarSenhaScreen extends StatefulWidget {
  const RecuperarSenhaScreen({super.key});

  @override
  State<RecuperarSenhaScreen> createState() => _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends State<RecuperarSenhaScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _enviar() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      avisar(context, 'Informe o e-mail da sua conta.', tipo: TipoAviso.info);
      return;
    }
    // TODO: chamar a rota de recuperação quando o back-end tiver uma.
    avisar(
      context,
      'A recuperação de senha por e-mail ainda não está disponível. '
      'Fale com o administrador do sistema para redefinir a sua senha.',
      tipo: TipoAviso.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CabecalhoAuth(
              titulo: 'Recuperar senha',
              descricao: 'Informe o e-mail da sua conta para receber as '
                  'instruções de redefinição de senha.',
            ),
            CampoVidro(
              controller: _emailController,
              hint: 'Email',
              icone: Icons.email,
              teclado: TextInputType.emailAddress,
              acao: TextInputAction.done,
              autofill: const [AutofillHints.email],
              aoEnviar: (_) => _enviar(),
            ),
            const SizedBox(height: 24),
            BotaoLaranja(texto: 'Enviar', carregando: false, onPressed: _enviar),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Lembrou a senha? ', style: StyleLogin.rodape),
                LinkSublinhado(
                  texto: 'Voltar ao login',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
