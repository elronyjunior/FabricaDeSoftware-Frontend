import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fabrica_software_app/screens/Treinamentos/importar_participantes.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _texto(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List _docx(String corpo) {
  final xml = '<?xml version="1.0"?><w:document><w:body>$corpo</w:body></w:document>';
  final zip = Archive()
    ..addFile(ArchiveFile.bytes('word/document.xml', utf8.encode(xml)));
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

String _p(String t) => '<w:p><w:r><w:t>$t</w:t></w:r></w:p>';
String _tc(String t) => '<w:tc>${_p(t)}</w:tc>';

void main() {
  test('txt: um nome por linha, com numeração e e-mail', () {
    final r = lerParticipantes('lista.txt', _texto(
        '1. Ana Souza\n\n- Bruno Lima - bruno@x.com\nCarla Dias <carla@x.com>\nana souza\n'));
    expect(r, const [
      ParticipanteImportado('Ana Souza'),
      ParticipanteImportado('Bruno Lima', 'bruno@x.com'),
      ParticipanteImportado('Carla Dias', 'carla@x.com'),
    ]);
  });

  test('csv com cabeçalho usa as colunas nome e e-mail', () {
    final r = lerParticipantes('lista.csv',
        _texto('CPF;Nome;E-mail\n123;João Silva;JOAO@x.com\n456;Maria;\n'));
    expect(r, const [
      ParticipanteImportado('João Silva', 'joao@x.com'),
      ParticipanteImportado('Maria'),
    ]);
  });

  test('csv do Excel em Latin-1 mantém os acentos', () {
    final r = lerParticipantes(
        'lista.csv', Uint8List.fromList(latin1.encode('Nome,Email\nJosé Conceição,jose@x.com\n')));
    expect(r, const [ParticipanteImportado('José Conceição', 'jose@x.com')]);
  });

  test('docx: parágrafos e tabela', () {
    final corpo = _p('Participantes') == '' ? '' : '${_p('Lista do curso')}'
        '<w:tbl><w:tr>${_tc('Nome')}${_tc('E-mail')}</w:tr>'
        '<w:tr>${_tc('Paula Reis')}${_tc('paula@x.com')}</w:tr></w:tbl>'
        '${_p('Rafael Melo')}';
    final r = lerParticipantes('lista.docx', _docx(corpo));
    expect(r, contains(const ParticipanteImportado('Paula Reis', 'paula@x.com')));
    expect(r, contains(const ParticipanteImportado('Rafael Melo')));
  });

  test('tipo não aceito', () {
    expect(() => lerParticipantes('lista.pdf', _texto('x')),
        throwsA(isA<FormatException>()));
  });
}
