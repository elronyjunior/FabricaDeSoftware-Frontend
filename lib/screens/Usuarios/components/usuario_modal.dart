import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:flutter/material.dart';
import 'package:fabrica_software_app/models/usuario.dart';
import 'package:provider/provider.dart';
import 'package:fabrica_software_app/providers/usuarios_provider.dart';

/// Níveis do banco (tipo `nivel_usuario` em db/schema.sql) e como aparecem.
const niveisUsuario = {
  'USUARIO': 'Usuário',
  'MASTER': 'Master',
  'ADMINISTRADOR': 'Administrador',
};

enum UsuarioModalMode {
  view,
  edit,
  delete,
  create,
}

class UsuarioModal extends StatefulWidget {
  final UsuarioModalMode mode;
  final Usuario? usuario;

  const UsuarioModal({
    super.key,
    required this.mode,
    this.usuario,
  });

  @override
  State<UsuarioModal> createState() => _UsuarioModalState();
}

class _UsuarioModalState extends State<UsuarioModal> {
  late TextEditingController _nomeController;
  late TextEditingController _emailController;
  late TextEditingController _nivelController;
  late TextEditingController _telefoneController;
  late TextEditingController _senhaController;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.usuario?.nome ?? '');
    _emailController = TextEditingController(text: widget.usuario?.email ?? '');
    // O banco só aceita os valores do tipo nivel_usuario (ver [niveisUsuario]);
    // um nível antigo fora da lista vira "Usuário".
    final nivel = (widget.usuario?.nivel ?? '').toUpperCase();
    _nivelController = TextEditingController(
        text: niveisUsuario.containsKey(nivel) ? nivel : 'USUARIO');
    _telefoneController = TextEditingController(text: widget.usuario?.telefone ?? '');
    _senhaController = TextEditingController(); // Senha começa vazia
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _nivelController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  bool get _visualizando => widget.mode == UsuarioModalMode.view;

  @override
  Widget build(BuildContext context) {
    if (widget.mode == UsuarioModalMode.delete) {
      return ConfirmacaoIdv(
        titulo: 'Excluir usuário',
        mensagem: '${widget.usuario!.nome} será excluído. '
            'Essa ação não pode ser desfeita.',
        rotuloAcao: 'Excluir usuário',
        carregando: _isLoading,
        aoConfirmar: _excluir,
      );
    }

    final (titulo, acao) = switch (widget.mode) {
      UsuarioModalMode.view => ('Detalhes do usuário', null),
      UsuarioModalMode.edit => ('Editar usuário', 'Salvar alterações'),
      _ => ('Novo usuário', 'Criar usuário'),
    };

    return PainelIdv(
      titulo: titulo,
      rotuloAcao: acao,
      carregando: _isLoading,
      aoConfirmar: widget.mode == UsuarioModalMode.edit ? _salvar : _criar,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final isCreate = widget.mode == UsuarioModalMode.create;

    final formContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SecaoIdv('Dados pessoais'),
        _campo('Nome', _nomeController, obrigatorio: true, dica: 'Nome completo'),
        LinhaCamposIdv(children: [
          _campo('E-mail', _emailController,
              obrigatorio: true,
              dica: 'nome@empresa.com',
              teclado: TextInputType.emailAddress,
              validar: _validarEmail),
          _campo('Telefone', _telefoneController,
              dica: '(00) 00000-0000', teclado: TextInputType.phone),
        ]),
        const SizedBox(height: 6),
        const SecaoIdv('Acesso'),
        if (_visualizando)
          // Só leitura: valorInicial em vez de criar um controller no build
          // (que nunca seria descartado).
          CampoIdv(
            rotulo: 'Nível',
            valorInicial:
                niveisUsuario[_nivelController.text] ?? _nivelController.text,
            somenteLeitura: true,
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RotuloIdv('Nível', obrigatorio: true),
                SelecaoIdv<String>(
                  hint: 'Escolha o nível',
                  valor: _nivelController.text,
                  itens: niveisUsuario.keys.toList(),
                  rotulo: (n) => niveisUsuario[n]!,
                  aoMudar: (n) => setState(
                      () => _nivelController.text = n ?? 'USUARIO'),
                ),
              ],
            ),
          ),
        if (!_visualizando)
          CampoIdv(
            rotulo: isCreate ? 'Senha' : 'Nova senha',
            controle: _senhaController,
            obrigatorio: isCreate,
            // Na edição, vazio mantém a senha (o CampoIdv não chama o
            // validar com o campo vazio).
            validar: (v) => v.length < 6
                ? 'A senha precisa ter no mínimo 6 caracteres'
                : null,
            ocultar: _obscurePassword,
            dica: isCreate ? null : 'Deixe em branco para manter a atual',
            sufixo: IconButton(
              tooltip: _obscurePassword ? 'Mostrar senha' : 'Esconder senha',
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
      ],
    );

    if (_visualizando) return formContent;
    return Form(key: _formKey, child: formContent);
  }

  Widget _campo(String rotulo, TextEditingController controle,
      {bool obrigatorio = false,
      String? dica,
      TextInputType? teclado,
      String? Function(String)? validar}) {
    return CampoIdv(
      rotulo: rotulo,
      controle: controle,
      obrigatorio: obrigatorio,
      somenteLeitura: _visualizando,
      dica: dica,
      teclado: teclado,
      validar: validar,
    );
  }

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validarEmail(String v) =>
      _emailRegex.hasMatch(v) ? null : 'Informe um e-mail válido';

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = {
      'nome': _nomeController.text,
      'email': _emailController.text.trim(),
      'nivel': _nivelController.text,
      'telefone': _telefoneController.text.isEmpty ? null : _telefoneController.text,
    };
    // Lógica do Backend: só manda senha se tiver valor
    if (_senhaController.text.isNotEmpty) {
      data['senha'] = _senhaController.text;
    }
    await _executar(
      () => context
          .read<UsuariosProvider>()
          .atualizarUsuario(widget.usuario!.id!, data),
      'Usuário atualizado.',
    );
  }

  Future<void> _excluir() => _executar(
        () => context.read<UsuariosProvider>().excluirUsuario(widget.usuario!.id!),
        'Usuário excluído.',
      );

  Future<void> _criar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = {
      'nome': _nomeController.text,
      'email': _emailController.text.trim(),
      'senha': _senhaController.text, // Obrigatória aqui
      'nivel': _nivelController.text,
      'telefone': _telefoneController.text.isEmpty ? null : _telefoneController.text,
    };
    await _executar(
      () => context.read<UsuariosProvider>().criarUsuario(data),
      'Usuário criado.',
    );
  }

  /// Roda a ação no provider: só fecha o painel se deu certo; na falha
  /// mantém o painel aberto (com os dados) e mostra o erro.
  Future<void> _executar(Future<void> Function() acao, String sucesso) async {
    setState(() => _isLoading = true);
    try {
      await acao();
      if (!mounted) return;
      Navigator.pop(context);
      avisarApp(sucesso, tipo: TipoAviso.sucesso);
    } catch (e) {
      if (!mounted) return;
      avisar(context, e.toString(), tipo: TipoAviso.erro);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
