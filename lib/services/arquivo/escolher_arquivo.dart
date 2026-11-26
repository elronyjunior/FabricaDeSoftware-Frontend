import 'dart:typed_data';

import 'escolher_arquivo_stub.dart'
    if (dart.library.js_interop) 'escolher_arquivo_web.dart' as impl;

/// Arquivo escolhido pelo usuário: nome (com extensão) e conteúdo.
class ArquivoEscolhido {
  const ArquivoEscolhido(this.nome, this.bytes);
  final String nome;
  final Uint8List bytes;
}

/// Abre o seletor de arquivos do navegador. [extensoes] no formato
/// `.csv`, `.txt`. Devolve null se o usuário cancelar.
///
/// Fora da web lança [UnsupportedError].
Future<ArquivoEscolhido?> escolherArquivo(List<String> extensoes) =>
    impl.escolherArquivo(extensoes);
