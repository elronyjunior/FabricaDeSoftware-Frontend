import 'package:fabrica_software_app/Widgets/Gestao/pagina_gestao.dart';
import 'package:fabrica_software_app/models/usuario.dart';
import 'package:fabrica_software_app/providers/usuarios_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Usuarios/components/Usuario_modal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Usuarios extends StatefulWidget {
  const Usuarios({super.key});

  @override
  State<Usuarios> createState() => _UsuariosState();
}

class _UsuariosState extends State<Usuarios> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsuariosProvider>().carregarUsuarios();
    });
  }

  /// Nível do banco (USUARIO, MASTER, ADMINISTRADOR) como aparece na tela.
  static String _tipoConta(Usuario u) =>
      switch ((u.nivel ?? '').toUpperCase()) {
        'ADMINISTRADOR' => 'Administrador',
        'MASTER' => 'Master',
        'USUARIO' => 'Usuário',
        '' => 'Usuário',
        final outro => outro[0] + outro.substring(1).toLowerCase(),
      };

  static Widget _etiquetaConta(String tipo) => switch (tipo) {
        'Administrador' => const EtiquetaGestao('Administrador',
            fundo: StyleProjetos.azulEscuro, corTexto: Colors.white),
        'Master' => const EtiquetaGestao('Master', fundo: Color(0xFFA9B4F0)),
        _ => EtiquetaGestao(tipo, fundo: const Color(0xFF7DC08A)),
      };

  @override
  Widget build(BuildContext context) {
    final usuarios = context.watch<UsuariosProvider>();

    return PaginaGestao<Usuario>(
      titulo: 'Gestão de Usuários',
      rotuloNovo: 'Criar Usuário',
      aoNovo: () => _abrirModalCriarUsuario(context),
      tituloLista: 'Lista de Usuários',
      singular: 'usuário',
      plural: 'usuários',
      itens: usuarios.usuarios ?? const [],
      carregando: usuarios.isLoading,
      erro: usuarios.error,
      aoRecarregar: usuarios.carregarUsuarios,
      nome: (u) => u.nome,
      textoBusca: (u) =>
          '${u.nome} ${u.email} ${u.telefone ?? ''} ${_tipoConta(u)}',
      rotuloFiltro: 'Tipo de conta',
      valorFiltro: _tipoConta,
      colunas: const [
        ColunaGestao('Nome de usuário', flex: 4),
        ColunaGestao('E-mail', flex: 4),
        ColunaGestao('Telefone', flex: 3),
        ColunaGestao('Tipo de conta', flex: 2, alinhamento: Alignment.center),
        ColunaGestao('Ações', flex: 2, alinhamento: Alignment.center),
      ],
      celulas: (u) => [
        NomeComAvatar(u.nome),
        TextoCelula(u.email),
        (u.telefone ?? '').trim().isEmpty
            ? const TextoCelula('—', secundario: true)
            : TextoCelula(u.telefone!),
        _etiquetaConta(_tipoConta(u)),
      ],
      acoes: (u) => AcoesGestao(
        aoVer: () => _abrirModalUsuario(context, u, UsuarioModalMode.view),
        aoEditar: () => _abrirModalUsuario(context, u, UsuarioModalMode.edit),
        aoExcluir: () =>
            _abrirModalUsuario(context, u, UsuarioModalMode.delete),
      ),
    );
  }
}

void _abrirModalUsuario(
    BuildContext context, Usuario usuario, UsuarioModalMode modo) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => UsuarioModal(mode: modo, usuario: usuario),
  );
}

void _abrirModalCriarUsuario(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const UsuarioModal(mode: UsuarioModalMode.create),
  );
}
