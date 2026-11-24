import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/models/endereco.dart';
import 'package:fabrica_software_app/screens/Clientes/components/mapa_endereco.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =====================================================================
// Endereço do cliente: aba "Endereço" do painel do cliente (antes abria
// num modal por cima do modal do cliente).
// =====================================================================

/// Campos do endereço. Quem cria (o painel do cliente) também descarta.
class EnderecoControles {
  final logradouro = TextEditingController();
  final cep = TextEditingController();
  final numero = TextEditingController();
  final bairro = TextEditingController();
  final cidade = TextEditingController();
  final estado = TextEditingController();
  final pais = TextEditingController(text: 'Brasil');
  final complemento = TextEditingController();

  List<TextEditingController> get _todos =>
      [logradouro, cep, numero, bairro, cidade, estado, pais, complemento];

  void preencher(Endereco e) {
    logradouro.text = e.logradouro;
    cep.text = formatarCep(e.cep);
    numero.text = e.numero ?? '';
    bairro.text = e.bairro ?? '';
    cidade.text = e.cidade;
    // Endereços antigos podem ter o nome do estado: mostra a sigla.
    estado.text = siglaUf(e.estado) ?? e.estado;
    pais.text = e.pais;
    complemento.text = e.complemento ?? '';
  }

  /// Corpo enviado ao back-end (mesmos campos de antes).
  Map<String, dynamic> dados() {
    String? opcional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return {
      'logradouro': logradouro.text.trim(),
      'cep': formatarCep(cep.text),
      'numero': opcional(numero),
      'bairro': opcional(bairro),
      'cidade': cidade.text.trim(),
      'estado': estado.text.trim().toUpperCase(),
      'pais': pais.text.trim(),
      'complemento': opcional(complemento),
    };
  }

  void dispose() {
    for (final c in _todos) {
      c.dispose();
    }
  }
}

/// Mapa + campos do endereço (vai dentro do Form do painel do cliente).
class FormularioEndereco extends StatefulWidget {
  const FormularioEndereco({
    super.key,
    required this.controles,
    this.somenteLeitura = false,
  });

  final EnderecoControles controles;
  final bool somenteLeitura;

  @override
  State<FormularioEndereco> createState() => _FormularioEnderecoState();
}

class _FormularioEnderecoState extends State<FormularioEndereco> {
  EnderecoControles get _c => widget.controles;

  /// Endereço já preenchido (edição/visualização), para centrar o mapa.
  String get _enderecoDigitado => [
        _c.logradouro.text,
        _c.numero.text,
        _c.cidade.text,
        _c.estado.text,
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
        e.logradouro!.toLowerCase() != _c.logradouro.text.trim().toLowerCase();
    setState(() {
      if (outraRua) _c.bairro.clear();
      _c.numero.text = e.numero ?? '';
      por(_c.cep, e.cep == null ? null : formatarCep(e.cep!));
      por(_c.logradouro, e.logradouro);
      por(_c.bairro, e.bairro);
      por(_c.cidade, e.cidade);
      por(_c.estado, siglaUf(e.uf));
      por(_c.pais, e.pais);
    });
  }

  Widget _campo(String rotulo, TextEditingController controle,
      {bool obrigatorio = false,
      String? dica,
      TextInputType? teclado,
      List<TextInputFormatter>? formatadores,
      String? Function(String)? validar}) {
    return CampoIdv(
      rotulo: rotulo,
      controle: controle,
      obrigatorio: obrigatorio,
      somenteLeitura: widget.somenteLeitura,
      dica: dica,
      teclado: teclado,
      formatadores: formatadores,
      validar: validar,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecaoIdv('Localização',
            descricao: widget.somenteLeitura
                ? null
                : 'Busque ou marque no mapa para preencher o endereço.'),
        MapaEndereco(
          somenteLeitura: widget.somenteLeitura,
          enderecoInicial: _enderecoDigitado,
          aoEscolher: _preencherPeloMapa,
        ),
        const SizedBox(height: 22),
        const SecaoIdv('Endereço'),
        LinhaCamposIdv(children: [
          _campo('CEP', _c.cep,
              obrigatorio: true,
              dica: '00000-000',
              teclado: TextInputType.number,
              formatadores: [_FormatoCep()],
              validar: (v) => RegExp(r'^\d{5}-\d{3}$').hasMatch(v)
                  ? null
                  : 'CEP com 8 dígitos (00000-000)'),
          _campo('Número', _c.numero, dica: 'Ex.: 120'),
        ]),
        _campo('Logradouro', _c.logradouro,
            obrigatorio: true, dica: 'Rua, avenida...'),
        LinhaCamposIdv(children: [
          _campo('Bairro', _c.bairro),
          _campo('Complemento', _c.complemento, dica: 'Sala, bloco...'),
        ]),
        LinhaCamposIdv(children: [
          _campo('Cidade', _c.cidade, obrigatorio: true),
          _campo('UF', _c.estado,
              obrigatorio: true,
              dica: 'SP',
              // Só 2 letras, sempre maiúsculas.
              formatadores: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                LengthLimitingTextInputFormatter(2),
                _Maiusculas(),
              ],
              validar: (v) => siglasUf.contains(v.toUpperCase())
                  ? null
                  : 'Use a sigla do estado (ex.: SP)'),
          _campo('País', _c.pais, obrigatorio: true),
        ]),
      ],
    );
  }
}


/// CEP: só números, com o hífen entrando sozinho (00000-000).
class _FormatoCep extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 8) d = d.substring(0, 8);
    final texto = d.length > 5 ? '${d.substring(0, 5)}-${d.substring(5)}' : d;
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// UF sempre em maiúsculas.
class _Maiusculas extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
