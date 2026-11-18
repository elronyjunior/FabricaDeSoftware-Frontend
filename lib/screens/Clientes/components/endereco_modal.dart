import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
// --- Ficheiro: lib/widgets/endereco_modal.dart ---

import 'package:fabrica_software_app/providers/endereco_provider.dart';
import 'package:flutter/material.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/models/endereco.dart';
import 'package:fabrica_software_app/screens/Clientes/components/mapa_endereco.dart';

enum EnderecoModalMode {
  view,
  edit,
  create,
}

class EnderecoModal extends StatefulWidget {
  final EnderecoModalMode mode;
  final Endereco? endereco;
  final EnderecosProvider enderecosProvider;

  const EnderecoModal({
    super.key,
    required this.mode,
    required this.enderecosProvider,
    this.endereco,
  });

  @override
  State<EnderecoModal> createState() => _EnderecoModalState();
}

class _EnderecoModalState extends State<EnderecoModal> {
  late TextEditingController _logradouroController;
  late TextEditingController _cepController;
  late TextEditingController _numeroController;
  late TextEditingController _bairroController;
  late TextEditingController _cidadeController;
  late TextEditingController _estadoController;
  late TextEditingController _paisController;
  late TextEditingController _complementoController;

  final _formKey = GlobalKey<FormState>();
  bool _isModalLoading = false;

  @override
  void initState() {
    super.initState();
    _logradouroController = TextEditingController(text: widget.endereco?.logradouro ?? '');
    _cepController = TextEditingController(text: widget.endereco?.cep ?? '');
    _numeroController = TextEditingController(text: widget.endereco?.numero ?? '');
    _bairroController = TextEditingController(text: widget.endereco?.bairro ?? '');
    _cidadeController = TextEditingController(text: widget.endereco?.cidade ?? '');
    _estadoController = TextEditingController(text: widget.endereco?.estado ?? '');
    _paisController = TextEditingController(text: widget.endereco?.pais ?? 'Brasil');
    _complementoController = TextEditingController(text: widget.endereco?.complemento ?? '');
  }

  @override
  void dispose() {
    _logradouroController.dispose();
    _cepController.dispose();
    _numeroController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    _paisController.dispose();
    _complementoController.dispose();
    super.dispose();
  }
  
  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() { _isModalLoading = true; });

    final provider = widget.enderecosProvider;

    final data = {
      'logradouro': _logradouroController.text,
      'cep': _cepController.text,
      'numero': _numeroController.text.isEmpty ? null : _numeroController.text,
      'bairro': _bairroController.text.isEmpty ? null : _bairroController.text,
      'cidade': _cidadeController.text,
      'estado': _estadoController.text,
      'pais': _paisController.text,
      'complemento': _complementoController.text.isEmpty ? null : _complementoController.text,
    };

    try {
      if (widget.mode == EnderecoModalMode.edit) {
        final enderecoAtualizado = await provider.atualizarEndereco(widget.endereco!.id!, data);
        if (!mounted) return;
        Navigator.pop(context, enderecoAtualizado.id);

      } else if (widget.mode == EnderecoModalMode.create) {
        final novoEndereco = await provider.criarEndereco(data);
        if (!mounted) return;
        Navigator.pop(context, novoEndereco.id);
      }
    } catch (e) {
      if (!mounted) return;
      avisar(context, 'Erro ao salvar endereço: $e', tipo: TipoAviso.erro);
    } finally {
      if (mounted) setState(() { _isModalLoading = false; });
    }
  }

  bool get _visualizando => widget.mode == EnderecoModalMode.view;

  @override
  Widget build(BuildContext context) {
    final (titulo, acao) = switch (widget.mode) {
      EnderecoModalMode.view => ('Endereço', null),
      EnderecoModalMode.edit => ('Editar endereço', 'Salvar endereço'),
      EnderecoModalMode.create => ('Novo endereço', 'Adicionar endereço'),
    };

    return PainelIdv(
      titulo: titulo,
      rotuloAcao: acao,
      carregando: _isModalLoading,
      aoConfirmar: _submitForm,
      largura: 600,
      child: Form(key: _formKey, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecaoIdv('Localização',
            descricao: _visualizando
                ? null
                : 'Busque ou marque no mapa para preencher o endereço.'),
        MapaEndereco(
          somenteLeitura: _visualizando,
          enderecoInicial: _enderecoDigitado,
          aoEscolher: _preencherPeloMapa,
        ),
        const SizedBox(height: 22),
        const SecaoIdv('Endereço'),
        LinhaCamposIdv(children: [
          _campo('CEP', _cepController,
              obrigatorio: true,
              dica: '00000-000',
              teclado: TextInputType.number),
          _campo('Número', _numeroController, dica: 'Ex.: 120'),
        ]),
        _campo('Logradouro', _logradouroController,
            obrigatorio: true, dica: 'Rua, avenida...'),
        LinhaCamposIdv(children: [
          _campo('Bairro', _bairroController),
          _campo('Complemento', _complementoController,
              dica: 'Sala, bloco...'),
        ]),
        LinhaCamposIdv(children: [
          _campo('Cidade', _cidadeController, obrigatorio: true),
          _campo('UF', _estadoController, obrigatorio: true, dica: 'SP'),
          _campo('País', _paisController, obrigatorio: true),
        ]),
      ],
    );
  }

  /// Endereço já preenchido (edição/visualização), para centrar o mapa.
  String get _enderecoDigitado => [
        _logradouroController.text,
        _numeroController.text,
        _cidadeController.text,
        _estadoController.text,
      ].where((p) => p.trim().isNotEmpty).join(', ');

  /// Ponto marcado no mapa: preenche os campos que o mapa conhece. O número
  /// é sempre o da nova busca (vazio quando ela não tem); o complemento
  /// fica como está.
  void _preencherPeloMapa(EnderecoDoMapa e) {
    void por(TextEditingController c, String? v) {
      if (v != null && v.isNotEmpty) c.text = v;
    }

    // Outra rua: o bairro antigo não vale mais.
    final outraRua = e.logradouro != null &&
        e.logradouro!.toLowerCase() !=
            _logradouroController.text.trim().toLowerCase();
    setState(() {
      if (outraRua) _bairroController.clear();
      _numeroController.text = e.numero ?? '';
      por(_cepController, e.cep);
      por(_logradouroController, e.logradouro);
      por(_bairroController, e.bairro);
      por(_cidadeController, e.cidade);
      por(_estadoController, e.uf);
      por(_paisController, e.pais);
    });
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
}
