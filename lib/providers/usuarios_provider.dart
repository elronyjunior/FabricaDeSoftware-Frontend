import 'package:flutter/foundation.dart';
import '../models/usuario.dart';
import '../services/base_api_service.dart';
import '../services/usuarios_service.dart';

class UsuariosProvider with ChangeNotifier {
  final _service = UsuariosService.instance;
  bool _isLoading = false;
  String? _error;
  List<Usuario>? _usuarios;
  Usuario? _usuarioSelecionado;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Usuario>? get usuarios => _usuarios;
  Usuario? get usuarioSelecionado => _usuarioSelecionado;

  Future<void> carregarUsuarios() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _usuarios = await _service.listarUsuarios();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> carregarUsuario(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _usuarioSelecionado = await _service.buscarUsuario(id);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Criar/atualizar/excluir lançam o erro (em vez de preencher `_error`):
  // `_error` é o erro de CARREGAMENTO e faz a PaginaGestao trocar a lista
  // toda por "Não foi possível carregar". Quem chama mostra o aviso.
  Future<void> criarUsuario(Map<String, dynamic> data) async {
    try {
      final usuario = await _service.criarUsuario(data);
      _usuarios?.add(usuario);
      notifyListeners();
    } catch (e) {
      throw _erroAcao(e, 'Não foi possível criar o usuário.');
    }
  }

  Future<void> atualizarUsuario(int id, Map<String, dynamic> data) async {
    try {
      final usuario = await _service.atualizarUsuario(id, data);
      final index = _usuarios?.indexWhere((u) => u.id == id);
      if (index != null && index != -1) {
        _usuarios?[index] = usuario;
      }
      if (_usuarioSelecionado?.id == id) {
        _usuarioSelecionado = usuario;
      }
      notifyListeners();
    } catch (e) {
      throw _erroAcao(e, 'Não foi possível atualizar o usuário.');
    }
  }

  Future<void> excluirUsuario(int id) async {
    try {
      await _service.excluirUsuario(id);
      _usuarios?.removeWhere((u) => u.id == id);
      if (_usuarioSelecionado?.id == id) {
        _usuarioSelecionado = null;
      }
      notifyListeners();
    } catch (e) {
      throw _erroAcao(e, 'Não foi possível excluir o usuário.');
    }
  }

  /// Mantém a mensagem da API (ApiException) e troca erros técnicos por
  /// um texto amigável.
  ApiException _erroAcao(Object e, String padrao) {
    if (e is ApiException && e.message.trim().isNotEmpty) return e;
    return ApiException(padrao);
  }

  void limparErro() {
    _error = null;
    notifyListeners();
  }

  void limparUsuarioSelecionado() {
    _usuarioSelecionado = null;
    notifyListeners();
  }
}