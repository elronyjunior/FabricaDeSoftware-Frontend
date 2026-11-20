import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/models/endereco.dart';
import 'package:fabrica_software_app/screens/Clientes/components/mapa_endereco.dart';
import 'package:flutter/material.dart';

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
    cep.text = e.cep;
    numero.text = e.numero ?? '';
    bairro.text = e.bairro ?? '';
    cidade.text = e.cidade;
    estado.text = e.estado;
    pais.text = e.pais;
    complemento.text = e.complemento ?? '';
  }

  /// Corpo enviado ao back-end (mesmos campos de antes).
  Map<String, dynamic> dados() {
    String? opcional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return {
      'logradouro': logradouro.text.trim(),
      'cep': cep.text.trim(),
      'numero': opcional(numero),
      'bairro': opcional(bairro),
      'cidade': cidade.text.trim(),
      'estado': estado.text.trim(),
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
      por(_c.cep, e.cep);
      por(_c.logradouro, e.logradouro);
      por(_c.bairro, e.bairro);
      por(_c.cidade, e.cidade);
      por(_c.estado, e.uf);
      por(_c.pais, e.pais);
    });
  }

  Widget _campo(String rotulo, TextEditingController controle,
      {bool obrigatorio = false, String? dica, TextInputType? teclado}) {
    return CampoIdv(
      rotulo: rotulo,
      controle: controle,
      obrigatorio: obrigatorio,
      somenteLeitura: widget.somenteLeitura,
      dica: dica,
      teclado: teclado,
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
              teclado: TextInputType.number),
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
          _campo('UF', _c.estado, obrigatorio: true, dica: 'SP'),
          _campo('País', _c.pais, obrigatorio: true),
        ]),
      ],
    );
  }
}
