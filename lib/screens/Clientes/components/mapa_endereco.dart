import 'dart:convert';

import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// =====================================================================
// Mapa do endereço (só front-end): mapa do OpenStreetMap, busca/tradução
// de ponto em endereço pelo Nominatim e CEP, rua e bairro conferidos no
// ViaCEP (base dos Correios, mais certa que o mapa para bairro e CEP).
// Todos são serviços públicos, sem chave. O ponto marcado não é salvo:
// ele só preenche os campos.
// =====================================================================

/// Endereço encontrado no mapa (campos vazios ficam null).
class EnderecoDoMapa {
  const EnderecoDoMapa({
    this.cep,
    this.logradouro,
    this.numero,
    this.bairro,
    this.cidade,
    this.uf,
    this.pais,
  });

  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? bairro;
  final String? cidade;
  final String? uf;
  final String? pais;

  EnderecoDoMapa copiar({
    String? cep,
    String? logradouro,
    String? numero,
    String? bairro,
    String? cidade,
    String? uf,
  }) =>
      EnderecoDoMapa(
        cep: cep ?? this.cep,
        logradouro: logradouro ?? this.logradouro,
        numero: numero ?? this.numero,
        bairro: bairro ?? this.bairro,
        cidade: cidade ?? this.cidade,
        uf: uf ?? this.uf,
        pais: pais,
      );

  /// Resposta do ViaCEP (um CEP).
  factory EnderecoDoMapa.doViaCep(Map<String, dynamic> json) {
    String? v(String chave) {
      final t = json[chave]?.toString().trim();
      return t == null || t.isEmpty ? null : t;
    }

    return EnderecoDoMapa(
      cep: v('cep'),
      logradouro: v('logradouro'),
      bairro: v('bairro'),
      cidade: v('localidade'),
      uf: v('uf'),
      pais: 'Brasil',
    );
  }

  factory EnderecoDoMapa.doNominatim(Map<String, dynamic> json) {
    final a = (json['address'] as Map?)?.cast<String, dynamic>() ?? {};
    String? primeiro(List<String> chaves) {
      for (final c in chaves) {
        final v = a[c]?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    // "BR-SP" -> "SP"
    final iso = a['ISO3166-2-lvl4']?.toString();
    final uf = iso != null && iso.contains('-') ? iso.split('-').last : null;

    return EnderecoDoMapa(
      cep: primeiro(['postcode']),
      logradouro: primeiro(['road', 'pedestrian', 'footway', 'path']),
      numero: primeiro(['house_number']),
      bairro: primeiro(['suburb', 'neighbourhood', 'quarter', 'city_district']),
      cidade: primeiro(['city', 'town', 'village', 'municipality']),
      uf: uf ?? primeiro(['state']),
      pais: primeiro(['country']),
    );
  }
}

class MapaEndereco extends StatefulWidget {
  const MapaEndereco({
    super.key,
    required this.aoEscolher,
    this.enderecoInicial,
    this.somenteLeitura = false,
  });

  /// Chamado quando um ponto é marcado (clique ou busca).
  final ValueChanged<EnderecoDoMapa> aoEscolher;

  /// Endereço já preenchido: o mapa abre centrado nele.
  final String? enderecoInicial;

  final bool somenteLeitura;

  @override
  State<MapaEndereco> createState() => _MapaEnderecoState();
}

class _MapaEnderecoState extends State<MapaEndereco> {
  static const _nominatim = 'https://nominatim.openstreetmap.org';
  static const _centroBrasil = LatLng(-14.24, -51.93);

  final _mapa = MapController();
  final _busca = TextEditingController();
  LatLng? _ponto;
  bool _buscando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final inicial = widget.enderecoInicial?.trim() ?? '';
    if (inicial.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _buscar(inicial, preencher: false));
    }
  }

  @override
  void dispose() {
    _busca.dispose();
    _mapa.dispose();
    super.dispose();
  }

  Future<dynamic> _get(String caminho, Map<String, String> params) async {
    final uri = Uri.parse('$_nominatim/$caminho').replace(queryParameters: {
      'format': 'jsonv2',
      'addressdetails': '1',
      'accept-language': 'pt-BR',
      ...params,
    });
    final resposta = await http.get(uri);
    if (resposta.statusCode != 200) {
      throw Exception('o serviço do mapa respondeu ${resposta.statusCode}');
    }
    return jsonDecode(utf8.decode(resposta.bodyBytes));
  }

  // ---------------- ViaCEP ----------------

  static String _soDigitos(String? t) =>
      (t ?? '').replaceAll(RegExp(r'\D'), '');

  static String _semAcento(String texto) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const para = 'aaaaaeeeeiiiiooooouuuucn';
    final saida = StringBuffer();
    for (final c in texto.toLowerCase().split('')) {
      final i = de.indexOf(c);
      saida.write(i >= 0 ? para[i] : c);
    }
    return saida.toString();
  }

  /// "Av. Três de Março" e "Avenida 3 de Março" -> "tres de marco".
  static String _nomeRua(String? rua) {
    const numeros = {
      '1': 'um', '2': 'dois', '3': 'tres', '4': 'quatro', '5': 'cinco',
      '6': 'seis', '7': 'sete', '8': 'oito', '9': 'nove', '10': 'dez',
    };
    var t = _semAcento(rua ?? '').trim();
    t = t.replaceAll(
        RegExp(r'^(avenida|av\.?|rua|r\.|estrada|rodovia|alameda|'
            r'travessa|praca)\s+'),
        '');
    t = t.replaceAllMapped(
        RegExp(r'\b(\d{1,2})\b'), (m) => numeros[m[1]] ?? m[1]!);
    return t
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _mesmaRua(String? a, String? b) {
    final x = _nomeRua(a), y = _nomeRua(b);
    return x.isNotEmpty && y.isNotEmpty && (x.contains(y) || y.contains(x));
  }

  Future<EnderecoDoMapa?> _viaCep(String cep) async {
    final digitos = _soDigitos(cep);
    if (digitos.length != 8) return null;
    try {
      final r = await http
          .get(Uri.parse('https://viacep.com.br/ws/$digitos/json/'));
      if (r.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(r.bodyBytes));
      if (json is! Map || json['erro'] != null) return null;
      return EnderecoDoMapa.doViaCep(json.cast());
    } catch (_) {
      return null;
    }
  }

  /// CEPs de uma rua (o ViaCEP pede UF, cidade e ao menos 3 letras da rua).
  Future<List<EnderecoDoMapa>> _viaCepRua(
      String uf, String cidade, String rua) async {
    final nome = _nomeRua(rua);
    if (uf.length != 2 || cidade.isEmpty || nome.length < 3) return [];
    try {
      final uri = Uri.parse('https://viacep.com.br/ws/'
          '${Uri.encodeComponent(uf)}/${Uri.encodeComponent(cidade)}/'
          '${Uri.encodeComponent(nome)}/json/');
      final r = await http.get(uri);
      if (r.statusCode != 200) return [];
      final json = jsonDecode(utf8.decode(r.bodyBytes));
      if (json is! List) return [];
      return [
        for (final item in json)
          if (item is Map) EnderecoDoMapa.doViaCep(item.cast()),
      ].where((e) => _mesmaRua(e.logradouro, rua)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Confere o que veio do mapa no ViaCEP: CEP, rua e bairro dos Correios
  /// valem mais que os do mapa (o bairro do mapa costuma vir errado).
  Future<EnderecoDoMapa> _conferir(EnderecoDoMapa mapa,
      {String? numero}) async {
    final e = mapa.copiar(numero: mapa.numero ?? numero);

    // 1) O CEP do mapa é da mesma rua: usa os dados dele.
    final peloCep = await _viaCep(e.cep ?? '');
    if (peloCep != null &&
        (e.logradouro == null || _mesmaRua(peloCep.logradouro, e.logradouro))) {
      return e.copiar(
        cep: peloCep.cep,
        logradouro: peloCep.logradouro,
        bairro: peloCep.bairro,
        cidade: peloCep.cidade,
        uf: peloCep.uf,
      );
    }

    // 2) Procura a rua no ViaCEP e fica com o CEP dela.
    if (e.logradouro != null && e.cidade != null && e.uf != null) {
      final ruas = await _viaCepRua(e.uf!, e.cidade!, e.logradouro!);
      if (ruas.isNotEmpty) {
        final cepMapa = _soDigitos(e.cep);
        final escolhida = ruas.firstWhere(
          (r) => _soDigitos(r.cep) == cepMapa,
          orElse: () => ruas.first,
        );
        return e.copiar(
          cep: escolhida.cep,
          logradouro: escolhida.logradouro,
          bairro: escolhida.bairro,
          cidade: escolhida.cidade,
          uf: escolhida.uf,
        );
      }
    }
    return e;
  }

  // ---------------- Busca e clique ----------------

  /// Número digitado na busca ("Av. Três de Março, 1317" -> "1317").
  static String? _numeroDigitado(String texto) {
    final m = RegExp(r'(?:,|\bn[ºo°]?\.?)\s*(\d{1,6})\b').firstMatch(texto);
    return m?[1];
  }

  void _moverPara(Map item) {
    final ponto = LatLng(double.parse(item['lat'].toString()),
        double.parse(item['lon'].toString()));
    setState(() => _ponto = ponto);
    _mapa.move(ponto, 17);
  }

  /// Busca um endereço ou CEP escrito e marca o lugar.
  Future<void> _buscar(String texto, {bool preencher = true}) async {
    final termo = texto.trim();
    if (termo.isEmpty) return;
    setState(() {
      _buscando = true;
      _erro = null;
    });
    try {
      // Só o CEP: os Correios dizem a rua; o mapa só mostra onde fica.
      if (_soDigitos(termo).length == 8 &&
          RegExp(r'^[\d\s.-]+$').hasMatch(termo)) {
        final cep = await _viaCep(termo);
        if (!mounted) return;
        if (cep == null) {
          setState(() => _erro = 'CEP $termo não encontrado.');
          return;
        }
        if (preencher) widget.aoEscolher(cep);
        final lista = await _get('search', {
          if (cep.logradouro != null) 'street': cep.logradouro!,
          if (cep.cidade != null) 'city': cep.cidade!,
          if (cep.uf != null) 'state': cep.uf!,
          'country': 'Brasil',
          'limit': '1',
        }) as List;
        if (mounted && lista.isNotEmpty) _moverPara(lista.first as Map);
        return;
      }

      final lista = await _get('search',
          {'q': termo, 'countrycodes': 'br', 'limit': '1'}) as List;
      if (!mounted) return;
      if (lista.isEmpty) {
        setState(() => _erro = 'Nenhum lugar encontrado para "$termo".');
        return;
      }
      final item = (lista.first as Map).cast<String, dynamic>();
      _moverPara(item);
      if (!preencher) return;
      final endereco = await _conferir(EnderecoDoMapa.doNominatim(item),
          numero: _numeroDigitado(termo));
      if (mounted) widget.aoEscolher(endereco);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não foi possível buscar: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  /// Clique no mapa: marca o ponto e traduz em endereço.
  Future<void> _marcar(LatLng ponto) async {
    if (widget.somenteLeitura) return;
    setState(() {
      _ponto = ponto;
      _buscando = true;
      _erro = null;
    });
    try {
      final json = await _get('reverse', {
        'lat': ponto.latitude.toString(),
        'lon': ponto.longitude.toString(),
        'zoom': '18',
      }) as Map;
      if (!mounted) return;
      if (json['error'] != null) {
        setState(() => _erro = 'Nenhum endereço encontrado nesse ponto.');
        return;
      }
      final endereco =
          await _conferir(EnderecoDoMapa.doNominatim(json.cast()));
      if (mounted) widget.aoEscolher(endereco);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível ler o endereço: $e');
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.somenteLeitura) ...[
          TextField(
            controller: _busca,
            style: fonteIdv(),
            cursorColor: CoresIdv.azul,
            textInputAction: TextInputAction.search,
            onSubmitted: _buscar,
            decoration: decoracaoCampoIdv(
              dica: 'Buscar endereço ou CEP (ex.: Av. Paulista, 1000)',
              prefixo: const Icon(Icons.search_rounded,
                  size: 20, color: CoresIdv.textoSecundario),
              sufixo: IconButton(
                tooltip: 'Buscar no mapa',
                onPressed: _buscando ? null : () => _buscar(_busca.text),
                icon: const Icon(Icons.arrow_forward_rounded,
                    color: StyleProjetos.azulEscuro),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CoresIdv.borda),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapa,
                options: MapOptions(
                  initialCenter: _centroBrasil,
                  initialZoom: 4,
                  // Acima de 19 o OpenStreetMap não tem imagem (fica borrado).
                  minZoom: 3,
                  maxZoom: 19,
                  onTap: (_, ponto) => _marcar(ponto),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'br.com.fabricadesoftware.app',
                  ),
                  if (_ponto != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _ponto!,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on_rounded,
                            size: 44, color: StyleProjetos.laranja),
                      ),
                    ]),
                  const SimpleAttributionWidget(
                    source: Text('OpenStreetMap'),
                  ),
                ],
              ),
              if (_buscando)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: _Carregando(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _erro ??
              (widget.somenteLeitura
                  ? 'Local aproximado do endereço.'
                  : 'Clique no mapa para marcar o local. Os campos abaixo '
                      'são preenchidos sozinhos (confira o número e o CEP).'),
          style: fonteIdv(
              tamanho: 12,
              cor: _erro != null ? CoresIdv.vermelho : CoresIdv.textoSecundario),
        ),
      ],
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x220F1030), blurRadius: 8),
        ],
      ),
      child: const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: StyleProjetos.laranja),
      ),
    );
  }
}
