import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'auth_service.dart';
import 'base_api_service.dart';

/// Foto de perfil: o link do servidor ou a imagem guardada neste navegador.
class FotoPerfil {
  const FotoPerfil({this.url, this.bytes});

  final String? url;
  final Uint8List? bytes;

  /// true quando a foto só existe neste navegador (o servidor ainda não
  /// aceita fotos; ver o markdown do back-end, seção "Perfil do usuário").
  bool get soLocal => url == null && bytes != null;

  ImageProvider? get imagem {
    if (bytes != null) return MemoryImage(bytes!);
    if (url != null && url!.isNotEmpty) return NetworkImage(url!);
    return null;
  }
}

/// Escolher, enviar e remover a foto de perfil.
///
/// Envia para `PUT /api/usuarios/:id/foto` (multipart, campo `foto`). Se o
/// servidor ainda não tiver essa rota (404/405), guarda a foto só neste
/// navegador, para ela já aparecer no perfil e no menu.
class FotoPerfilService {
  FotoPerfilService._();
  static final instance = FotoPerfilService._();

  /// Tamanho máximo aceito (depois de reduzida para 512 px).
  static const limiteBytes = 2 * 1024 * 1024;

  static String _chave(int idUsuario) => 'foto_perfil_$idUsuario';

  Uri _rota(int idUsuario) =>
      Uri.parse('${ApiConfig.baseUrl}/usuarios/$idUsuario/foto');

  Future<Map<String, String>> _cabecalhos() async {
    final token = await AuthService.instance.token;
    return {...ApiConfig.getAuthHeaders(token), 'Accept': 'application/json'};
  }

  /// Abre o seletor de imagens. Devolve null se a pessoa cancelar.
  Future<({Uint8List bytes, String nome})?> escolher() async {
    final arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (arquivo == null) return null;
    final bytes = await arquivo.readAsBytes();
    if (bytes.length > limiteBytes) {
      throw ApiException('A imagem é grande demais. Use uma de até 2 MB.');
    }
    return (bytes: bytes, nome: arquivo.name);
  }

  /// Foto guardada neste navegador (enquanto o servidor não aceita fotos).
  Future<Uint8List?> local(int idUsuario) async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_chave(idUsuario));
    if (texto == null) return null;
    try {
      return base64Decode(texto);
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardarLocal(int idUsuario, Uint8List? bytes) async {
    final prefs = await SharedPreferences.getInstance();
    if (bytes == null) {
      await prefs.remove(_chave(idUsuario));
    } else {
      await prefs.setString(_chave(idUsuario), base64Encode(bytes));
    }
  }

  /// Envia a foto. Sem a rota no servidor, guarda só neste navegador.
  Future<FotoPerfil> salvar(int idUsuario, Uint8List bytes, String nome) async {
    final http.StreamedResponse resposta;
    try {
      final req = http.MultipartRequest('PUT', _rota(idUsuario))
        ..headers.addAll(await _cabecalhos())
        ..files.add(http.MultipartFile.fromBytes('foto', bytes, filename: nome));
      resposta = await req.send();
    } catch (_) {
      throw ApiException('Não foi possível falar com o servidor.');
    }

    if (resposta.statusCode == 404 || resposta.statusCode == 405) {
      await _guardarLocal(idUsuario, bytes);
      return FotoPerfil(bytes: bytes);
    }
    final corpo = await resposta.stream.bytesToString();
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw ApiException('Não foi possível enviar a foto.', resposta.statusCode);
    }
    await _guardarLocal(idUsuario, null);
    String? url;
    try {
      url = (jsonDecode(corpo) as Map)['foto_url'] as String?;
    } catch (_) {}
    return url == null ? FotoPerfil(bytes: bytes) : FotoPerfil(url: url);
  }

  /// Remove a foto (no servidor, se a rota existir, e neste navegador).
  Future<void> remover(int idUsuario) async {
    try {
      final r = await http.delete(_rota(idUsuario), headers: await _cabecalhos());
      if (r.statusCode >= 400 && r.statusCode != 404 && r.statusCode != 405) {
        throw ApiException('Não foi possível remover a foto.', r.statusCode);
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      // Sem servidor: ainda assim tira a foto deste navegador.
    }
    await _guardarLocal(idUsuario, null);
  }
}
