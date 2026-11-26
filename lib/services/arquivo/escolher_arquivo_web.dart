import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'escolher_arquivo.dart';

Future<ArquivoEscolhido?> escolherArquivo(List<String> extensoes) {
  final concluido = Completer<ArquivoEscolhido?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = extensoes.join(',');

  Future<void> ler() async {
    final arquivo = input.files?.item(0);
    if (arquivo == null) {
      if (!concluido.isCompleted) concluido.complete(null);
      return;
    }
    try {
      final buffer = await arquivo.arrayBuffer().toDart;
      if (!concluido.isCompleted) {
        concluido.complete(
            ArquivoEscolhido(arquivo.name, buffer.toDart.asUint8List()));
      }
    } catch (e) {
      if (!concluido.isCompleted) concluido.completeError(e);
    }
  }

  // O callback passado ao JS precisa devolver void (não Future).
  input.onchange = ((web.Event _) {
    ler();
  }).toJS;

  // Fechar o seletor sem escolher (navegadores atuais disparam "cancel").
  input.addEventListener(
      'cancel',
      ((web.Event _) {
        if (!concluido.isCompleted) concluido.complete(null);
      }).toJS);

  input.click();
  return concluido.future;
}
