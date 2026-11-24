import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class BaseApiService {
  final String endpoint;
  
  BaseApiService(this.endpoint);

  /// Chamado quando o servidor diz que o token expirou (ligado no main.dart
  /// para sair da conta e voltar ao login).
  static void Function()? aoSessaoExpirada;

  /// O back responde 401, ou 403 com "Token inválido ou expirado".
  static bool sessaoExpirou(http.Response response) {
    if (response.statusCode == 401) return true;
    if (response.statusCode != 403) return false;
    return mensagemDoCorpo(response)?.toLowerCase().contains('token') ?? false;
  }

  /// Mensagem de erro do corpo: o back usa `message` ou `error`. Corpo que
  /// não é JSON (ex.: página HTML de proxy) devolve null em vez de estourar.
  static String? mensagemDoCorpo(http.Response response) {
    try {
      final corpo = jsonDecode(utf8.decode(response.bodyBytes));
      if (corpo is Map) {
        final msg = corpo['message'] ?? corpo['error'];
        if (msg != null && msg.toString().trim().isNotEmpty) {
          return msg.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Avisa o app (uma vez por resposta) e lança o erro de sessão expirada.
  static Never lancarSessaoExpirada() {
    aoSessaoExpirada?.call();
    throw ApiException('Sua sessão expirou. Entre de novo.', 401);
  }

  @protected
  Uri buildUri([String? path]) {
    final url = '${ApiConfig.baseUrl}$endpoint${path ?? ''}';
    return Uri.parse(url);
  }

  @protected
  Future<Map<String, String>> getHeaders() async {
    final token = await AuthService.instance.token;
    final headers = ApiConfig.getAuthHeaders(token);
    headers['Content-Type'] = 'application/json';
    headers['Accept'] = 'application/json';
    return headers;
  }

  @protected
  Future<T> handleResponse<T>(http.Response response, T Function(dynamic json) parser) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      dynamic json;
      try {
        final texto = utf8.decode(response.bodyBytes);
        json = texto.trim().isEmpty ? null : jsonDecode(texto);
      } on FormatException {
        // Resposta que não é JSON: mensagem amigável em vez do erro cru.
        throw ApiException('O servidor respondeu num formato inesperado.');
      }
      return parser(json);
    }
    if (sessaoExpirou(response)) lancarSessaoExpirada();
    final doCorpo = mensagemDoCorpo(response);
    if (response.statusCode == 403) {
      throw ApiException(doCorpo ?? 'Sem permissão para acessar este recurso.', 403);
    } else if (response.statusCode == 404) {
      throw ApiException(doCorpo ?? 'Recurso não encontrado.', 404);
    } else if (response.statusCode >= 500) {
      // Erro 5xx pode trazer detalhe técnico do banco: mostra o genérico.
      throw ApiException('Erro interno do servidor.', response.statusCode);
    }
    throw ApiException(doCorpo ?? 'Erro na requisição', response.statusCode);
  }

  // Métodos HTTP diretos para testes
  Future<http.Response> get(String path) async {
    return _executeWithRetry(() async => await http.get(
      buildUri(path),
      headers: await getHeaders(),
    ), idempotente: true);
  }

  Future<http.Response> post(String path, dynamic data) async {
    return _executeWithRetry(() async => await http.post(
      buildUri(path),
      headers: await getHeaders(),
      body: jsonEncode(data),
    ));
  }

  Future<http.Response> put(String path, dynamic data) async {
    return _executeWithRetry(() async => await http.put(
      buildUri(path),
      headers: await getHeaders(),
      body: jsonEncode(data),
    ));
  }

  Future<http.Response> deleteByPath(String path) async {
    return _executeWithRetry(() async => await http.delete(
      buildUri(path),
      headers: await getHeaders(),
    ));
  }

  static const _maxRetries = 2;

  /// Só repete em falha de rede quando [idempotente] (GET): repetir um
  /// POST/PUT/DELETE que talvez já tenha chegado ao servidor duplica registros.
  Future<http.Response> _executeWithRetry(
      Future<http.Response> Function() request,
      {bool idempotente = false}) async {
    int retries = 0;
    var tentouRenovar = false;
    while (true) {
      final http.Response response;
      try {
        response = await request();
      } catch (e) {
        if (!idempotente || retries >= _maxRetries) rethrow;
        retries++;
        continue;
      }
      if (sessaoExpirou(response)) {
        // Token recusado: o pedido não foi processado, então dá para
        // reenviar (mesmo POST) uma vez se o refresh der certo.
        if (!tentouRenovar) {
          tentouRenovar = true;
          final renovou =
              await AuthService.instance.refreshToken().catchError((_) => false);
          if (renovou) continue;
        }
        lancarSessaoExpirada();
      }
      return response;
    }
  }

  Future<List<T>> getAll<T>(T Function(Map<String, dynamic> json) fromJson, {String? path}) async {
    final response = await _executeWithRetry(() async => await http.get(
      buildUri(path),
      headers: await getHeaders(),
    ), idempotente: true);

    return handleResponse(response, (json) {
      if (json is! List) throw ApiException('Resposta inválida do servidor');
      return json.map((item) => fromJson(item as Map<String, dynamic>)).toList();
    });
  }

  Future<T> getById<T>(int id, T Function(Map<String, dynamic> json) fromJson) async {
    final response = await _executeWithRetry(() async => await http.get(
      buildUri('/$id'),
      headers: await getHeaders(),
    ), idempotente: true);

    return handleResponse(response, (json) {
      if (json is! Map<String, dynamic>) {
        throw ApiException('Resposta inválida do servidor');
      }
      return fromJson(json);
    });
  }

  Future<T> create<T>(Map<String, dynamic> data, T Function(Map<String, dynamic> json) fromJson) async {
    final response = await _executeWithRetry(() async => await http.post(
      buildUri(),
      headers: await getHeaders(),
      body: jsonEncode(data),
    ));

    return handleResponse(response, (json) {
      if (json is! Map<String, dynamic>) {
        throw ApiException('Resposta inválida do servidor');
      }
      return fromJson(json);
    });
  }

  Future<T> update<T>(int id, Map<String, dynamic> data, T Function(Map<String, dynamic> json) fromJson) async {
    final response = await _executeWithRetry(() async => await http.put(
      buildUri('/$id'),
      headers: await getHeaders(),
      body: jsonEncode(data),
    ));

    return handleResponse(response, (json) {
      if (json is! Map<String, dynamic>) {
        throw ApiException('Resposta inválida do servidor');
      }
      return fromJson(json);
    });
  }

  Future<void> delete(int id) async {
    final response = await _executeWithRetry(() async => await http.delete(
      buildUri('/$id'),
      headers: await getHeaders(),
    ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      throw ApiException(
          mensagemDoCorpo(response) ?? 'Erro ao excluir', response.statusCode);
    }
  }
}