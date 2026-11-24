import 'package:fabrica_software_app/Widgets/Barra_lateral/Barra_Lateral.dart';
import 'package:fabrica_software_app/Widgets/Gestao/pagina_gestao.dart';
import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/models/usuario.dart';
import 'package:fabrica_software_app/providers/auth_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/components/escala_design.dart';
import 'package:fabrica_software_app/screens/Usuarios/components/usuario_modal.dart';
import 'package:fabrica_software_app/services/auth_service.dart';
import 'package:fabrica_software_app/services/base_api_service.dart';
import 'package:fabrica_software_app/services/foto_perfil_service.dart';
import 'package:fabrica_software_app/services/usuario_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// =====================================================================
// Perfil do usuário logado: dados da conta (com edição no painel lateral)
// e senha/segurança (troca de senha e exclusão da conta).
// =====================================================================

class Account extends StatefulWidget {
  const Account({super.key});

  @override
  State<Account> createState() => _AccountState();
}

class _AccountState extends State<Account> {
  final _servico = UsuarioService();

  /// Dados vindos do back-end (atualizam o que está guardado no login).
  Usuario? _usuario;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final auth = context.read<AuthProvider>();
    final id = auth.userId ?? await AuthService.instance.userId;
    if (id == null) {
      if (mounted) setState(() => _carregando = false);
      return;
    }
    try {
      final u = await _servico.getUsuario(id);
      if (!mounted) return;
      setState(() => _usuario = u);
      if (u.fotoUrl != null && u.fotoUrl!.isNotEmpty) {
        auth.definirFoto(FotoPerfil(url: u.fotoUrl));
      }
      if (u.nome != auth.nome || u.email != auth.email) {
        await auth.atualizarPerfil(nome: u.nome, email: u.email);
      }
    } catch (_) {
      // Sem conexão: mostra o que está guardado no login.
    }
    if (mounted) setState(() => _carregando = false);
  }

  /// Usuário atual: o do back-end ou, sem ele, o guardado no login.
  Usuario _atual(AuthProvider auth) =>
      _usuario ??
      Usuario(
        id: auth.userId,
        nome: auth.nome ?? '',
        email: auth.email ?? '',
        nivel: auth.userNivel,
      );

  Future<void> _editar(Usuario atual) async {
    final salvo = await mostrarDialogo<Usuario>(
      context: context,
      builder: (_) => _PainelEditarPerfil(usuario: atual),
    );
    if (salvo == null || !mounted) return;
    setState(() => _usuario = salvo);
    await context
        .read<AuthProvider>()
        .atualizarPerfil(nome: salvo.nome, email: salvo.email);
    if (!mounted) return;
    avisarApp('Perfil atualizado.', tipo: TipoAviso.sucesso);
  }

  Future<void> _alterarSenha(Usuario atual) async {
    final alterou = await mostrarDialogo<bool>(
      context: context,
      builder: (_) => _PainelAlterarSenha(usuario: atual),
    );
    if (alterou == true) avisarApp('Senha alterada.', tipo: TipoAviso.sucesso);
  }

  Future<void> _excluirConta(Usuario atual) async {
    final excluiu = await mostrarDialogo<bool>(
      context: context,
      builder: (_) => _ConfirmarExclusao(usuario: atual),
    );
    if (excluiu == true && mounted) await sairDaConta(context);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = LayoutPrincipal.menuFixo(context);

    return Scaffold(
      drawer: BarraLateral.drawer(context),
      backgroundColor: desktop ? Colors.transparent : null,
      body: DecoratedBox(
        decoration: desktop
            ? const BoxDecoration()
            : const BoxDecoration(gradient: StyleProjetos.gradienteFundo),
        child: SafeArea(
          child: desktop
              ? EscalaDesign(
                  larguraBase: LayoutPrincipal.larguraBase -
                      LayoutPrincipal.recuoConteudo,
                  child: _conteudo(true),
                )
              : _conteudo(false),
        ),
      ),
    );
  }

  Widget _conteudo(bool desktop) {
    final auth = context.watch<AuthProvider>();
    final usuario = _atual(auth);

    return SingleChildScrollView(
      padding: desktop
          ? const EdgeInsets.fromLTRB(25, 62, 36, 32)
          : const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- Cabeçalho ----------------
          Row(
            children: [
              if (!desktop)
                Builder(
                  builder: (ctx) => IconButton(
                    tooltip: 'Abrir menu',
                    icon: const Icon(Icons.menu,
                        color: StyleProjetos.azulEscuro),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              Expanded(
                child: Text(
                  'Perfil do usuário',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: desktop
                      ? StyleProjetos.titulo
                      : StyleProjetos.titulo.copyWith(fontSize: 24),
                ),
              ),
            ],
          ),
          SizedBox(height: desktop ? 48 : 24),

          if (_carregando && _usuario == null && usuario.nome.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                  child: CircularProgressIndicator(color: CoresIdv.laranja)),
            )
          else
            _Conteudo(
              usuario: usuario,
              largo: desktop,
              aoEditar: () => _editar(usuario),
              aoAlterarSenha: () => _alterarSenha(usuario),
              aoExcluir: () => _excluirConta(usuario),
            ),
        ],
      ),
    );
  }
}

String _nivelLegivel(String? nivel) =>
    niveisUsuario[(nivel ?? '').toUpperCase()] ?? (nivel ?? 'Usuário');

String _iniciais(String nome) {
  final partes =
      nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  final ultima = partes.length > 1 ? partes.last[0] : '';
  return (partes.first[0] + ultima).toUpperCase();
}

// =====================================================================
// Conteúdo: cartão do perfil, dados da conta, senha e exclusão
// =====================================================================

class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.usuario,
    required this.largo,
    required this.aoEditar,
    required this.aoAlterarSenha,
    required this.aoExcluir,
  });

  final Usuario usuario;
  final bool largo;
  final VoidCallback aoEditar;
  final VoidCallback aoAlterarSenha;
  final VoidCallback aoExcluir;

  @override
  Widget build(BuildContext context) {
    final cartao = _CartaoPerfil(usuario: usuario);
    final dados = Container(
      decoration: StyleProjetos.painel(),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Título do bloco com o Editar à direita.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: SecaoIdv('Dados da conta',
                    descricao: 'Para mudar o nível de acesso, fale com um '
                        'administrador (Gestão de usuários).'),
              ),
              const SizedBox(width: 16),
              BotaoSecundarioIdv(
                rotulo: 'Editar perfil',
                icone: Icons.edit_outlined,
                aoTocar: aoEditar,
              ),
            ],
          ),
          _LinhaDado(rotulo: 'Nome', valor: usuario.nome, empilhado: !largo),
          _LinhaDado(rotulo: 'E-mail', valor: usuario.email, empilhado: !largo),
          _LinhaDado(rotulo: 'Telefone', valor: usuario.telefone, empilhado: !largo),
          _LinhaDado(
            rotulo: 'Nível de acesso',
            valor: _nivelLegivel(usuario.nivel),
            ultima: true,
            empilhado: !largo,
          ),
        ],
      ),
    );

    // Senha: só a linha com o botão; a troca acontece no painel lateral.
    final senha = Container(
      decoration: StyleProjetos.painel(),
      padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
      child: _LinhaAcao(
        titulo: 'Senha',
        descricao: 'Use sua senha para entrar no sistema. Quem entra com o '
            'Google não tem senha cadastrada aqui.',
        acao: BotaoSecundarioIdv(
          rotulo: 'Alterar senha',
          icone: Icons.lock_outline_rounded,
          aoTocar: aoAlterarSenha,
        ),
      ),
    );

    final perigo = Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x59D64545)),
      ),
      child: _LinhaAcao(
        titulo: 'Excluir conta',
        descricao: 'Apaga sua conta e seu acesso ao sistema. '
            'Essa ação não pode ser desfeita.',
        icone: Icons.warning_amber_rounded,
        acao: BotaoPrincipalIdv(
          rotulo: 'Excluir conta',
          perigo: true,
          aoTocar: aoExcluir,
        ),
      ),
    );

    if (!largo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cartao,
          const SizedBox(height: 20),
          dados,
          const SizedBox(height: 20),
          senha,
          const SizedBox(height: 20),
          perigo,
        ],
      );
    }
    const larguraCartao = 280.0;
    const espaco = 24.0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mesma altura: o cartão da foto acompanha o bloco de dados.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: larguraCartao, child: cartao),
                const SizedBox(width: espaco),
                Expanded(child: dados),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: larguraCartao + espaco),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [senha, const SizedBox(height: 20), perigo],
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha "título + descrição" com uma ação à direita (Senha, Excluir conta).
/// Em largura pequena, o botão desce para baixo do texto.
class _LinhaAcao extends StatelessWidget {
  const _LinhaAcao({
    required this.titulo,
    required this.descricao,
    required this.acao,
    this.icone,
  });

  final String titulo;
  final String descricao;
  final Widget acao;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final texto = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icone != null) ...[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0x1FD64545),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 22, color: CoresIdv.vermelho),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: fonteIdv(tamanho: 16, peso: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                descricao,
                style: fonteIdv(
                    tamanho: 13, cor: CoresIdv.textoSecundario, altura: 1.4),
              ),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 520) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [texto, const SizedBox(height: 14), acao],
        );
      }
      return Row(
        children: [
          Expanded(child: texto),
          const SizedBox(width: 20),
          acao,
        ],
      );
    });
  }
}

/// Cartão com o avatar (iniciais), o nome, o e-mail e o nível.
class _CartaoPerfil extends StatefulWidget {
  const _CartaoPerfil({required this.usuario});

  final Usuario usuario;

  @override
  State<_CartaoPerfil> createState() => _CartaoPerfilState();
}

class _CartaoPerfilState extends State<_CartaoPerfil> {
  bool _enviando = false;

  Future<void> _trocarFoto() async {
    final id = widget.usuario.id;
    if (id == null) return;
    final auth = context.read<AuthProvider>();
    try {
      final escolhida = await FotoPerfilService.instance.escolher();
      // O seletor de arquivo é assíncrono: a tela pode ter saído.
      if (escolhida == null || !mounted) return;
      setState(() => _enviando = true);
      final foto = await FotoPerfilService.instance
          .salvar(id, escolhida.bytes, escolhida.nome);
      auth.definirFoto(foto);
      avisarApp(
        foto.soLocal
            ? 'Foto salva neste navegador. Ela vai para o servidor quando '
                'o back-end aceitar fotos.'
            : 'Foto atualizada.',
        tipo: foto.soLocal ? TipoAviso.info : TipoAviso.sucesso,
      );
    } on ApiException catch (e) {
      avisarApp(e.message);
    } catch (_) {
      avisarApp('Não foi possível usar essa imagem. Tente outra.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _removerFoto() async {
    final id = widget.usuario.id;
    if (id == null) return;
    final auth = context.read<AuthProvider>();
    setState(() => _enviando = true);
    try {
      await FotoPerfilService.instance.remover(id);
      auth.definirFoto(const FotoPerfil());
      avisarApp('Foto removida.', tipo: TipoAviso.sucesso);
    } on ApiException catch (e) {
      avisarApp(e.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;
    final foto = context.watch<AuthProvider>().foto;
    final imagem = foto.imagem;

    return Container(
      decoration: StyleProjetos.painel(),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar: a foto ou as iniciais.
          Container(
            width: 112,
            height: 112,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: StyleProjetos.azulEscuro,
              shape: BoxShape.circle,
              image: imagem == null
                  ? null
                  : DecorationImage(image: imagem, fit: BoxFit.cover),
            ),
            child: _enviando
                ? Container(
                    color: const Color(0x8C0F1030),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    ),
                  )
                : imagem == null
                    ? Text(
                        _iniciais(usuario.nome),
                        style: fonteIdv(
                            tamanho: 38,
                            peso: FontWeight.w700,
                            cor: Colors.white),
                      )
                    : null,
          ),
          const SizedBox(height: 16),
          Text(
            usuario.nome.isEmpty ? 'Usuário' : usuario.nome,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: fonteIdv(tamanho: 18, peso: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            usuario.email,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: fonteIdv(tamanho: 13, cor: CoresIdv.textoSecundario),
          ),
          const SizedBox(height: 12),
          EtiquetaGestao(
            _nivelLegivel(usuario.nivel),
            fundo: CoresIdv.azulSuave,
            corTexto: StyleProjetos.azulEscuro,
          ),
          const SizedBox(height: 20),
          // Foto: enviar/trocar e remover.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              BotaoSecundarioIdv(
                rotulo: imagem == null ? 'Enviar foto' : 'Trocar foto',
                icone: Icons.upload_rounded,
                aoTocar: _enviando ? null : _trocarFoto,
              ),
              if (imagem != null)
                TextButton(
                  onPressed: _enviando ? null : _removerFoto,
                  style: TextButton.styleFrom(
                    foregroundColor: CoresIdv.vermelho,
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text('Remover',
                      style: fonteIdv(
                          tamanho: 14,
                          peso: FontWeight.w600,
                          cor: CoresIdv.vermelho)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            foto.soLocal
                ? 'Foto salva só neste navegador por enquanto.'
                : 'PNG ou JPG, até 2 MB.',
            textAlign: TextAlign.center,
            style: fonteIdv(tamanho: 12, cor: CoresIdv.textoSecundario),
          ),
        ],
      ),
    );
  }
}

/// Uma linha "rótulo — valor" dos dados da conta.
class _LinhaDado extends StatelessWidget {
  const _LinhaDado({
    required this.rotulo,
    required this.valor,
    this.ultima = false,
    this.empilhado = false,
  });

  final String rotulo;
  final String? valor;
  final bool ultima;

  /// Tela estreita: rótulo em cima do valor. (Sem LayoutBuilder: o bloco
  /// fica num IntrinsicHeight, que não aceita LayoutBuilder dentro.)
  final bool empilhado;

  @override
  Widget build(BuildContext context) {
    final vazio = valor == null || valor!.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : const Border(
                bottom: BorderSide(color: StyleProjetos.divisoria)),
      ),
      child: Builder(builder: (context) {
        final rotuloW = Text(rotulo,
            style: fonteIdv(
                tamanho: 13,
                peso: FontWeight.w500,
                cor: CoresIdv.textoSecundario));
        final valorW = SelectableText(
          vazio ? 'Não informado' : valor!,
          style: fonteIdv(
            tamanho: 15,
            cor: vazio ? CoresIdv.textoSecundario : CoresIdv.texto,
          ),
        );
        // Estreito: rótulo em cima do valor.
        if (empilhado) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [rotuloW, const SizedBox(height: 4), valorW],
          );
        }
        return Row(
          children: [
            SizedBox(width: 170, child: rotuloW),
            Expanded(child: valorW),
          ],
        );
      }),
    );
  }
}

// =====================================================================
// Painel "Alterar senha"
// =====================================================================

class _PainelAlterarSenha extends StatefulWidget {
  const _PainelAlterarSenha({required this.usuario});

  final Usuario usuario;

  @override
  State<_PainelAlterarSenha> createState() => _PainelAlterarSenhaState();
}

class _PainelAlterarSenhaState extends State<_PainelAlterarSenha> {
  final _form = GlobalKey<FormState>();
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _mostrar = false;
  bool _salvando = false;

  /// Erro da senha atual vindo do servidor (mostrado embaixo do campo).
  String? _erroAtual;

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Widget _olho() => IconButton(
        tooltip: _mostrar ? 'Esconder senhas' : 'Mostrar senhas',
        icon: Icon(
          _mostrar ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: CoresIdv.textoSecundario,
        ),
        onPressed: () => setState(() => _mostrar = !_mostrar),
      );

  Future<void> _salvar() async {
    setState(() => _erroAtual = null);
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _salvando = true);
    try {
      final confere = await AuthService.instance
          .conferirSenha(widget.usuario.email, _atual.text);
      if (!mounted) return; // o painel pode ter sido fechado na espera
      if (!confere) {
        setState(() {
          _erroAtual = 'A senha atual não confere.';
          _salvando = false;
        });
        _form.currentState?.validate();
        return;
      }
      final u = widget.usuario;
      await UsuarioService().updateUsuario(Usuario(
        id: u.id,
        nome: u.nome,
        email: u.email,
        nivel: u.nivel,
        telefone: u.telefone,
        senha: _nova.text,
      ));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        avisar(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _salvando = false);
        avisar(context, 'Não foi possível alterar a senha. Tente novamente.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PainelIdv(
      titulo: 'Alterar senha',
      rotuloAcao: 'Salvar nova senha',
      carregando: _salvando,
      aoConfirmar: _salvar,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SecaoIdv('Senha atual',
                descricao: 'Confirme a senha que você usa hoje para entrar.'),
            CampoIdv(
              rotulo: 'Senha atual',
              controle: _atual,
              obrigatorio: true,
              ocultar: !_mostrar,
              sufixo: _olho(),
              aoMudar: (_) {
                if (_erroAtual != null) setState(() => _erroAtual = null);
              },
              validar: (_) => _erroAtual,
            ),
            const SizedBox(height: 6),
            const SecaoIdv('Nova senha',
                descricao: 'Use pelo menos 6 caracteres.'),
            CampoIdv(
              rotulo: 'Nova senha',
              controle: _nova,
              obrigatorio: true,
              ocultar: !_mostrar,
              validar: (v) {
                if (v.length < 6) return 'Use pelo menos 6 caracteres.';
                if (v == _atual.text) {
                  return 'A nova senha precisa ser diferente da atual.';
                }
                return null;
              },
            ),
            CampoIdv(
              rotulo: 'Confirmar nova senha',
              controle: _confirmacao,
              obrigatorio: true,
              ocultar: !_mostrar,
              validar: (v) =>
                  v == _nova.text ? null : 'As senhas não são iguais.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmação de exclusão da própria conta (com carregando e erro).
class _ConfirmarExclusao extends StatefulWidget {
  const _ConfirmarExclusao({required this.usuario});

  final Usuario usuario;

  @override
  State<_ConfirmarExclusao> createState() => _ConfirmarExclusaoState();
}

class _ConfirmarExclusaoState extends State<_ConfirmarExclusao> {
  bool _carregando = false;

  Future<void> _excluir() async {
    final id = widget.usuario.id;
    if (id == null) return;
    setState(() => _carregando = true);
    try {
      await UsuarioService().deleteUsuario(id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregando = false);
      avisarApp(
        'Não foi possível excluir a conta. Ela pode estar ligada a '
        'projetos ou equipes; peça ajuda a um administrador.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConfirmacaoIdv(
      titulo: 'Excluir sua conta',
      mensagem: 'Sua conta (${widget.usuario.email}) será excluída e você '
          'sairá do sistema. Essa ação não pode ser desfeita.',
      rotuloAcao: 'Excluir conta',
      carregando: _carregando,
      aoConfirmar: _excluir,
    );
  }
}

// =====================================================================
// Painel "Editar perfil"
// =====================================================================

class _PainelEditarPerfil extends StatefulWidget {
  const _PainelEditarPerfil({required this.usuario});

  final Usuario usuario;

  @override
  State<_PainelEditarPerfil> createState() => _PainelEditarPerfilState();
}

class _PainelEditarPerfilState extends State<_PainelEditarPerfil> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.usuario.nome);
  late final _email = TextEditingController(text: widget.usuario.email);
  late final _telefone =
      TextEditingController(text: widget.usuario.telefone ?? '');
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _salvando = true);
    try {
      final u = widget.usuario;
      final salvo = await UsuarioService().updateUsuario(Usuario(
        id: u.id,
        nome: _nome.text.trim(),
        email: _email.text.trim(),
        // O nível não muda aqui: vai o atual (o banco não aceita vazio).
        nivel: u.nivel,
        telefone: _telefone.text.trim().isEmpty ? null : _telefone.text.trim(),
      ));
      if (mounted) Navigator.pop(context, salvo);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        avisar(
          context,
          e.message.toLowerCase().contains('duplicate') ||
                  e.message.toLowerCase().contains('unique')
              ? 'Esse e-mail já é usado por outra conta.'
              : e.message,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _salvando = false);
        avisar(context, 'Não foi possível salvar o perfil. Tente novamente.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PainelIdv(
      titulo: 'Editar perfil',
      rotuloAcao: 'Salvar alterações',
      carregando: _salvando,
      aoConfirmar: _salvar,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SecaoIdv('Dados pessoais'),
            CampoIdv(
              rotulo: 'Nome',
              controle: _nome,
              obrigatorio: true,
              dica: 'Nome completo',
            ),
            LinhaCamposIdv(children: [
              CampoIdv(
                rotulo: 'E-mail',
                controle: _email,
                obrigatorio: true,
                dica: 'nome@empresa.com',
                teclado: TextInputType.emailAddress,
                validar: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
                    ? null
                    : 'Informe um e-mail válido.',
              ),
              CampoIdv(
                rotulo: 'Telefone',
                controle: _telefone,
                dica: '(00) 00000-0000',
                teclado: TextInputType.phone,
              ),
            ]),
            const SizedBox(height: 6),
            const SecaoIdv('Acesso'),
            CampoIdv(
              rotulo: 'Nível de acesso',
              valorInicial: _nivelLegivel(widget.usuario.nivel),
              somenteLeitura: true,
            ),
            Text(
              'O e-mail é o que você usa para entrar. O nível só um '
              'administrador altera, em Gestão de usuários.',
              style: fonteIdv(
                  tamanho: 12, cor: CoresIdv.textoSecundario, altura: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
