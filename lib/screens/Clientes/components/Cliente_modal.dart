import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/providers/endereco_provider.dart';
import 'package:fabrica_software_app/screens/Clientes/components/endereco_modal.dart';
import 'package:flutter/material.dart';
import 'package:fabrica_software_app/models/cliente.dart';
import 'package:provider/provider.dart';
import 'package:fabrica_software_app/providers/clientes_provider.dart';

enum ClienteModalMode {
  view,
  edit,
  delete,
  create,
}

class ClienteModal extends StatefulWidget {
  final ClienteModalMode mode;
  final Cliente? cliente;
  final EnderecosProvider enderecosProvider;

  const ClienteModal({
    super.key,
    required this.mode,
    required this.enderecosProvider,
    this.cliente,
  });

  @override
  State<ClienteModal> createState() => _ClienteModalState();
}

class _ClienteModalState extends State<ClienteModal> {
  late TextEditingController _razaoSocialController;
  late TextEditingController _emailController;
  late TextEditingController _cnpjController;
  late TextEditingController _telefoneController;
  late TextEditingController _contatoController;
  late TextEditingController _setorController;

  int? _tempEnderecoId;

  /// Um formulário por aba, para levar à aba que tem campo com erro.
  final _formKey = GlobalKey<FormState>();
  final _formEnderecoKey = GlobalKey<FormState>();
  final _endereco = EnderecoControles();
  bool _isClienteModalLoading = false;

  /// 0 = Dados da empresa, 1 = Endereço.
  int _aba = 0;
  bool _carregandoEndereco = false;

  @override
  void initState() {
    super.initState();
    // Aqui usamos ?. e ??, então não dá erro se cliente for null
    _razaoSocialController =
        TextEditingController(text: widget.cliente?.razaoSocial ?? '');
    _emailController = TextEditingController(text: widget.cliente?.email ?? '');
    _cnpjController = TextEditingController(text: widget.cliente?.cnpj ?? '');
    _telefoneController =
        TextEditingController(text: widget.cliente?.telefone ?? '');
    _contatoController =
        TextEditingController(text: widget.cliente?.contato ?? '');
    _setorController = TextEditingController(text: widget.cliente?.setor ?? '');

    _tempEnderecoId = widget.cliente?.enderecoId;
    if (_tempEnderecoId != null) _carregarEndereco();
  }

  Future<void> _carregarEndereco() async {
    setState(() => _carregandoEndereco = true);
    try {
      final e = await widget.enderecosProvider.buscarEndereco(_tempEnderecoId!);
      _endereco.preencher(e);
    } catch (e) {
      if (mounted) avisar(context, 'Erro ao buscar o endereço: $e');
    }
    if (mounted) setState(() => _carregandoEndereco = false);
  }

  @override
  void dispose() {
    _razaoSocialController.dispose();
    _emailController.dispose();
    _cnpjController.dispose();
    _telefoneController.dispose();
    _contatoController.dispose();
    _setorController.dispose();
    _endereco.dispose();
    super.dispose();
  }

  bool get _visualizando => widget.mode == ClienteModalMode.view;

  @override
  Widget build(BuildContext context) {
    final fechar = () => Navigator.pop(context);

    if (widget.mode == ClienteModalMode.delete) {
      return ConfirmacaoIdv(
        titulo: 'Excluir cliente',
        mensagem: '${widget.cliente!.razaoSocial} será excluído. '
            'Essa ação não pode ser desfeita.',
        rotuloAcao: 'Excluir cliente',
        carregando: _isClienteModalLoading,
        aoConfirmar: () => _deleteCliente(fechar),
      );
    }

    final (titulo, acao) = switch (widget.mode) {
      ClienteModalMode.view => ('Detalhes do cliente', null),
      ClienteModalMode.edit => ('Editar cliente', 'Salvar alterações'),
      _ => ('Novo cliente', 'Criar cliente'),
    };

    return PainelIdv(
      titulo: titulo,
      rotuloAcao: acao,
      carregando: _isClienteModalLoading,
      aoConfirmar: () => _submitClienteForm(fechar),
      largura: 640,
      abas: const ['Dados da empresa', 'Endereço'],
      abaAtual: _aba,
      aoTrocarAba: (i) => setState(() => _aba = i),
      // As duas abas ficam montadas (o que foi digitado não se perde ao
      // trocar); só a atual aparece e ocupa espaço.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Visibility(
            visible: _aba == 0,
            maintainState: true,
            child: Form(key: _formKey, child: _buildBody(context)),
          ),
          Visibility(
            visible: _aba == 1,
            maintainState: true,
            child: Form(
              key: _formEnderecoKey,
              child: _carregandoEndereco
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: CoresIdv.laranja)),
                    )
                  : FormularioEndereco(
                      controles: _endereco,
                      somenteLeitura: _visualizando,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SecaoIdv('Dados da empresa'),
        _campo('Razão social', _razaoSocialController, obrigatorio: true),
        LinhaCamposIdv(children: [
          _campo('CNPJ', _cnpjController,
              obrigatorio: true, dica: '00.000.000/0000-00'),
          _campo('Setor', _setorController, dica: 'Ex.: Varejo'),
        ]),
        const SizedBox(height: 6),
        const SecaoIdv('Contato'),
        _campo('E-mail', _emailController,
            obrigatorio: true,
            dica: 'contato@empresa.com',
            teclado: TextInputType.emailAddress),
        LinhaCamposIdv(children: [
          _campo('Telefone', _telefoneController,
              dica: '(00) 00000-0000', teclado: TextInputType.phone),
          _campo('Pessoa de contato', _contatoController,
              dica: 'Nome de quem atende'),
        ]),
      ],
    );
  }

  Widget _campo(String rotulo, TextEditingController controle,
      {bool obrigatorio = false, String? dica, TextInputType? teclado}) {
    return CampoIdv(
      rotulo: rotulo,
      controle: controle,
      obrigatorio: obrigatorio,
      somenteLeitura: _visualizando,
      dica: dica,
      teclado: teclado,
    );
  }

  Future<void> _submitClienteForm(VoidCallback onSuccess) async {
    // Cada aba valida o seu formulário; com erro, abre a aba dele.
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _aba = 0);
      return;
    }
    if (!(_formEnderecoKey.currentState?.validate() ?? false)) {
      setState(() => _aba = 1);
      avisar(context, 'Preencha o endereço do cliente.', tipo: TipoAviso.info);
      return;
    }

    setState(() => _isClienteModalLoading = true);
    try {
      // 1) Endereço: atualiza o que já existe ou cria um novo.
      final dadosEndereco = _endereco.dados();
      final endereco = _tempEnderecoId != null
          ? await widget.enderecosProvider
              .atualizarEndereco(_tempEnderecoId!, dadosEndereco)
          : await widget.enderecosProvider.criarEndereco(dadosEndereco);
      _tempEnderecoId = endereco.id;

      // 2) Cliente, já com o endereço.
      final data = {
        'razao_social': _razaoSocialController.text,
        'cnpj': _cnpjController.text,
        'email': _emailController.text,
        'telefone':
            _telefoneController.text.isEmpty ? null : _telefoneController.text,
        'setor': _setorController.text.isEmpty ? null : _setorController.text,
        'contato':
            _contatoController.text.isEmpty ? null : _contatoController.text,
        'endereco_id': _tempEnderecoId,
      };
      if (!mounted) return;
      if (widget.mode == ClienteModalMode.edit) {
        await context
            .read<ClientesProvider>()
            .atualizarCliente(widget.cliente!.id!, data);
      } else {
        await context.read<ClientesProvider>().criarCliente(data);
      }
      onSuccess();
    } catch (e) {
      if (mounted)
        avisar(context, 'Erro ao salvar cliente: $e', tipo: TipoAviso.erro);
    } finally {
      if (mounted) setState(() => _isClienteModalLoading = false);
    }
  }

  Future<void> _deleteCliente(VoidCallback onSuccess) async {
    setState(() {
      _isClienteModalLoading = true;
    });
    try {
      await context
          .read<ClientesProvider>()
          .excluirCliente(widget.cliente!.id!);
      onSuccess();
    } catch (e) {
      avisar(context, 'Erro ao excluir cliente: $e', tipo: TipoAviso.erro);
    } finally {
      setState(() {
        _isClienteModalLoading = false;
      });
    }
  }
}
