import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

// =====================================================================
// Leitura da lista de participantes a partir de .csv, .txt ou .docx.
// Tudo no navegador: cada nome encontrado vira um POST na rota de aluno
// que já existe.
//
// Formatos aceitos (um participante por linha):
//   - "Nome"                         - "Nome;email" / "Nome,email" (csv)
//   - "Nome <email>" / "Nome - email" - tabela do Word (Nome | E-mail)
//   - CSV com cabeçalho: as colunas "nome" e "email"/"e-mail" são usadas,
//     e as outras ignoradas.
// =====================================================================

const extensoesParticipantes = ['.csv', '.txt', '.docx'];

class ParticipanteImportado {
  const ParticipanteImportado(this.nome, [this.email = '']);
  final String nome;
  final String email;

  @override
  bool operator ==(Object other) =>
      other is ParticipanteImportado &&
      other.nome == nome &&
      other.email == email;

  @override
  int get hashCode => Object.hash(nome, email);

  @override
  String toString() => email.isEmpty ? nome : '$nome <$email>';
}

final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
final _numeracao = RegExp(r'^\s*(\d+\s*[.)\-–]|[•\-–*])\s*');

/// Lê os participantes do arquivo. Lança [FormatException] se o tipo não
/// for aceito ou o .docx estiver corrompido.
List<ParticipanteImportado> lerParticipantes(String nomeArquivo, Uint8List bytes) {
  final ext = nomeArquivo.contains('.')
      ? nomeArquivo.substring(nomeArquivo.lastIndexOf('.')).toLowerCase()
      : '';
  final linhas = switch (ext) {
    '.docx' => _linhasDocx(bytes),
    '.csv' || '.txt' => const LineSplitter().convert(_decodificar(bytes)),
    _ => throw const FormatException('Use um arquivo .csv, .txt ou .docx.'),
  };
  return participantesDasLinhas(linhas, virgulaSepara: ext == '.csv');
}

/// Converte linhas de texto em participantes, sem repetidos.
List<ParticipanteImportado> participantesDasLinhas(
  List<String> linhas, {
  bool virgulaSepara = false,
}) {
  final resultado = <ParticipanteImportado>[];
  final vistos = <String>{};
  int? colNome;
  int? colEmail;

  for (var i = 0; i < linhas.length; i++) {
    final linha = linhas[i].trim();
    if (linha.isEmpty) continue;
    final celulas = _celulas(linha, virgulaSepara);

    // Cabeçalho ("Nome;E-mail;CPF"): guarda as colunas e pula a linha.
    final normal = celulas.map(_normalizar).toList();
    final iNome = normal.indexWhere((c) =>
        c == 'nome' || c == 'nome completo' || c == 'participante' || c == 'aluno');
    if (iNome >= 0 && !_email.hasMatch(linha)) {
      colNome = iNome;
      final iEmail = normal.indexWhere((c) => c == 'email' || c == 'e-mail');
      colEmail = iEmail >= 0 ? iEmail : null;
      continue;
    }

    String nome;
    String email = '';
    if (colNome != null && celulas.length > 1) {
      nome = colNome < celulas.length ? celulas[colNome] : '';
      if (colEmail != null && colEmail < celulas.length) {
        email = _email.firstMatch(celulas[colEmail])?.group(0) ?? '';
      }
    } else if (celulas.length > 1) {
      email = celulas
              .map((c) => _email.firstMatch(c)?.group(0))
              .firstWhere((e) => e != null, orElse: () => null) ??
          '';
      nome = celulas.firstWhere(
          (c) => !_email.hasMatch(c) && RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(c),
          orElse: () => '');
    } else {
      // Linha única: "Nome <email>", "Nome - email" ou só o nome.
      email = _email.firstMatch(linha)?.group(0) ?? '';
      nome = email.isEmpty ? linha : linha.replaceFirst(email, ' ');
    }

    nome = _limparNome(nome);
    if (nome.isEmpty || !RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(nome)) continue;
    email = email.toLowerCase();

    final chave = chaveParticipante(nome, email);
    if (vistos.add(chave)) resultado.add(ParticipanteImportado(nome, email));
  }
  return resultado;
}

/// Chave para achar repetidos: o e-mail, ou o nome sem acentos/caixa.
String chaveParticipante(String nome, String email) =>
    email.trim().isNotEmpty ? email.trim().toLowerCase() : _normalizar(nome);

List<String> _celulas(String linha, bool virgulaSepara) {
  final separador = linha.contains('\t')
      ? '\t'
      : linha.contains(';')
          ? ';'
          : (virgulaSepara && linha.contains(',') ? ',' : null);
  if (separador == null) return [linha];
  return linha
      .split(separador)
      .map((c) => c.trim().replaceAll(RegExp(r'^"|"$'), '').trim())
      .toList();
}

String _limparNome(String nome) {
  var n = nome.replaceFirst(_numeracao, '');
  n = n.replaceAll(RegExp(r'[<>()\[\]"]'), ' ');
  n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Separadores que sobram no fim ("Ana Souza -", "Ana Souza;").
  n = n.replaceAll(RegExp(r'^[\s\-–;,:|]+|[\s\-–;,:|]+$'), '');
  return n;
}

String _normalizar(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final b = StringBuffer();
  for (final r in s.trim().runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    b.write(i >= 0 ? para[i] : c);
  }
  return b.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// UTF-8; se não for (CSV salvo pelo Excel em português vem em
/// Windows-1252), cai para Latin-1, que acerta os acentos comuns.
String _decodificar(Uint8List bytes) {
  var inicio = 0;
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    inicio = 3; // BOM
  }
  final corpo = bytes.sublist(inicio);
  try {
    return utf8.decode(corpo);
  } on FormatException {
    return latin1.decode(corpo);
  }
}

/// Texto do .docx: cada parágrafo é uma linha, e cada linha de tabela vira
/// uma linha com as células separadas por tabulação.
List<String> _linhasDocx(Uint8List bytes) {
  final ArchiveFile? doc;
  try {
    doc = ZipDecoder().decodeBytes(bytes).findFile('word/document.xml');
  } catch (_) {
    throw const FormatException('Não foi possível ler o arquivo .docx.');
  }
  if (doc == null) {
    throw const FormatException('Não foi possível ler o arquivo .docx.');
  }
  final xml = utf8.decode(doc.content as List<int>, allowMalformed: true);

  String textoDe(String trecho) => _xmlTexto(trecho);

  final linhas = <String>[];
  final linhaTabela = RegExp(r'<w:tr[ >].*?</w:tr>', dotAll: true);
  final celula = RegExp(r'<w:tc[ >].*?</w:tc>', dotAll: true);
  final paragrafo = RegExp(r'<w:p[ >].*?</w:p>|<w:p/>', dotAll: true);

  var resto = 0;
  for (final tr in linhaTabela.allMatches(xml)) {
    // Parágrafos antes desta linha de tabela.
    for (final p in paragrafo.allMatches(xml.substring(resto, tr.start))) {
      linhas.add(textoDe(p.group(0)!));
    }
    linhas.add(celula
        .allMatches(tr.group(0)!)
        .map((c) => textoDe(c.group(0)!).trim())
        .join('\t'));
    resto = tr.end;
  }
  for (final p in paragrafo.allMatches(xml.substring(resto))) {
    linhas.add(textoDe(p.group(0)!));
  }
  return linhas;
}

String _xmlTexto(String trecho) {
  final b = StringBuffer();
  final partes = RegExp(r'<w:t(?:\s[^>]*)?>([^<]*)</w:t>|<w:tab/>|</w:p>');
  for (final m in partes.allMatches(trecho)) {
    final t = m.group(0)!;
    if (t == '<w:tab/>') {
      b.write('\t');
    } else if (t == '</w:p>') {
      b.write(' ');
    } else {
      b.write(m.group(1));
    }
  }
  return b
      .toString()
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
