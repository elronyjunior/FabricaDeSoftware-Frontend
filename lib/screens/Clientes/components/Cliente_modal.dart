import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/providers/endereco_provider.dart';
import 'package:fabrica_software_app/screens/Clientes/components/endereco_modal.dart';
import 'package:flutter/material.dart';
import 'package:fabrica_software_app/models/cliente.dart';
import 'package:provider/provider.dart';
import 'package:fabrica_software_app/providers/clientes_provider.dart';
import 'package:fabrica_software_app/models/endereco.dart';

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
  final _formKey = GlobalKey<FormState>();
  bool _isClienteModalLoading = false;

  @override
  void initState() {
    super.initState();
    // Aqui usamos ?. e ??, então não dá erro se cliente for null
    _razaoSocialController = TextEditingController(text: widget.cliente?.razaoSocial ?? '');
    _emailController = TextEditingController(text: widget.cliente?.email ?? '');
    _cnpjController = TextEditingController(text: widget.cliente?.cnpj ?? '');
    _telefoneController = TextEditingController(text: widget.cliente?.telefone ?? '');
    _contatoController = TextEditingController(text: widget.cliente?.contato ?? '');
    _setorController = TextEditingController(text: widget.cliente?.setor ?? '');

    _tempEnderecoId = widget.cliente?.enderecoId;
  }

  @override
  void dispose() {
    _razaoSocialController.dispose();
    _emailController.dispose();
    _cnpjController.dispose();
    _telefoneController.dispose();
    _contatoController.dispose();
    _setorController.dispose();
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
      child: Form(key: _formKey, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final temEndereco = _tempEnderecoId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SecaoIdv('Dados da empresa'),
        _campo('Razão social', _razaoSocialController, obrigatorio: true),
        LinhaCamposIdv(children: [
          _campo('CNPJ', _cnpjController, obrigatorio: true,
              dica: '00.000.000/0000-00'),
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
        const SizedBox(height: 6),
        SecaoIdv('Endereço',
            descricao: _visualizando
                ? null
                : 'Obrigatório para salvar o cliente.'),
        _CartaoEndereco(
          temEndereco: temEndereco,
          visualizando: _visualizando,
          aoTocar: () => _abrirModalEndereco(context),
        ),
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

  void _abrirModalEndereco(BuildContext context) async {
    EnderecoModalMode modoFilho;

    switch (widget.mode) {
      case ClienteModalMode.view:
        modoFilho = EnderecoModalMode.view;
        break;
      case ClienteModalMode.edit:
        modoFilho = (_tempEnderecoId == null) ? EnderecoModalMode.create : EnderecoModalMode.edit;
        break;
      case ClienteModalMode.create:
        modoFilho = EnderecoModalMode.create;
        break;
      default:
        return;
    }

    Endereco? enderecoAtual;
    if (_tempEnderecoId != null) {
      setState(() { _isClienteModalLoading = true; });
      try {
        enderecoAtual = await widget.enderecosProvider.buscarEndereco(_tempEnderecoId!);
      } catch (e) {
        avisar(context, 'Erro ao buscar endereço: $e', tipo: TipoAviso.erro);
        setState(() { _isClienteModalLoading = false; });
        return;
      }
      setState(() { _isClienteModalLoading = false; });
    }

    final novoEnderecoId = await mostrarDialogo<int>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (ctx) => EnderecoModal(
        mode: modoFilho,
        endereco: enderecoAtual,
        enderecosProvider: widget.enderecosProvider,
      ),
    );

    if (novoEnderecoId != null) {
      setState(() {
        _tempEnderecoId = novoEnderecoId;
      });
    }
  }

  Future<void> _submitClienteForm(VoidCallback onSuccess) async {
    if (_tempEnderecoId == null) {
      avisar(context, 'Erro: Endereço é obrigatório.', tipo: TipoAviso.erro);
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      setState(() { _isClienteModalLoading = true; });

      final data = {
        'razao_social': _razaoSocialController.text,
        'cnpj': _cnpjController.text,
        'email': _emailController.text,
        'telefone': _telefoneController.text.isEmpty ? null : _telefoneController.text,
        'setor': _setorController.text.isEmpty ? null : _setorController.text,
        'contato': _contatoController.text.isEmpty ? null : _contatoController.text,
        'endereco_id': _tempEnderecoId,
      };

      try {
        if (widget.mode == ClienteModalMode.edit) {
          await context.read<ClientesProvider>().atualizarCliente(widget.cliente!.id!, data);
        } else {
          await context.read<ClientesProvider>().criarCliente(data);
        }
        onSuccess();
      } catch (e) {
        avisar(context, 'Erro ao salvar cliente: $e', tipo: TipoAviso.erro);
      } finally {
        setState(() { _isClienteModalLoading = false; });
      }
    }
  }

  Future<void> _deleteCliente(VoidCallback onSuccess) async {
    setState(() { _isClienteModalLoading = true; });
    try {
      await context.read<ClientesProvider>().excluirCliente(widget.cliente!.id!);
      onSuccess();
    } catch (e) {
      avisar(context, 'Erro ao excluir cliente: $e', tipo: TipoAviso.erro);
    } finally {
      setState(() { _isClienteModalLoading = false; });
    }
  }
}

/// Linha do endereço: mostra se já tem endereço e abre o painel dele.
class _CartaoEndereco extends StatelessWidget {
  const _CartaoEndereco({
    required this.temEndereco,
    required this.visualizando,
    required this.aoTocar,
  });

  final bool temEndereco;
  final bool visualizando;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final rotulo = visualizando
        ? 'Ver endereço'
        : temEndereco
            ? 'Editar endereço'
            : 'Adicionar endereço';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: CoresIdv.campo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CoresIdv.borda),
      ),
      child: Row(
        children: [
          Icon(
            temEndereco
                ? Icons.location_on_rounded
                : Icons.location_off_outlined,
            color: temEndereco ? CoresIdv.laranja : CoresIdv.textoSecundario,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              temEndereco ? 'Endereço cadastrado' : 'Nenhum endereço cadastrado',
              style: fonteIdv(
                  peso: FontWeight.w500,
                  cor: temEndereco ? CoresIdv.texto : CoresIdv.textoSecundario),
            ),
          ),
          if (!visualizando || temEndereco)
            BotaoSecundarioIdv(
              rotulo: rotulo,
              icone: Icons.edit_location_alt_outlined,
              aoTocar: aoTocar,
            ),
        ],
      ),
    );
  }
}
