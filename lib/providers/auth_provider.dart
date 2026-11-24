import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/base_api_service.dart';
import '../services/foto_perfil_service.dart';

class AuthProvider with ChangeNotifier {
  final _authService = AuthService.instance;
  
  bool _isLoading = false;
  String? _error;
  bool? _isAuthenticated;
  
  // --- CORREÇÃO: Adicionado o campo ID que faltava ---
  int? _userId; 
  String? _userNivel;
  String? _email;
  String? _nome;

  AuthProvider() {
    _init();
  }

  // Getters
  bool? get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // --- CORREÇÃO: Getter público para o ID ---
  int? get userId => _userId; 
  
  String? get userNivel => _userNivel;
  String? get email => _email;
  String? get nome => _nome;

  Future<void> _init() async {
    _isAuthenticated = await _authService.isAuthenticated;
    
    if (_isAuthenticated ?? false) {
      _userId = await _authService.userId; // Carrega ID ao iniciar
      _userNivel = await _authService.userNivel;
      _email = await _authService.userEmail;
      _nome = await _authService.userName;
      await carregarFoto();
    }
    notifyListeners();
  }

  Future<bool> login(String email, String senha) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.login(email, senha);
      _isLoading = false;
      
      if (!success) {
        _error ??= 'Email ou senha incorretos.';
      } else {
        _isAuthenticated = true;
        // --- CORREÇÃO: Atualiza o ID imediatamente após login ---
        _userId = await _authService.userId; 
        _userNivel = await _authService.userNivel;
        _email = email; 
        _nome = await _authService.userName;
        await carregarFoto();
      }
      notifyListeners();
      return success;
    } on ApiException catch (e) {
      _isLoading = false;
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String nome,
    required String email,
    required String senha,
    String? telefone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.register(
        nome: nome,
        email: email,
        senha: senha,
        telefone: telefone,
      );
      _isLoading = false;

      if (!success) {
        _error ??= 'Não foi possível criar a conta.';
      } else {
        _isAuthenticated = true;
        _userId = await _authService.userId;
        _userNivel = await _authService.userNivel;
        _email = email;
        _nome = nome;
      }
      notifyListeners();
      return success;
    } on ApiException catch (e) {
      _isLoading = false;
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.loginWithGoogle();
      _isLoading = false;
      
      if (!success) {
        _error = 'Falha no login com Google.';
      } else {
        _isAuthenticated = true;
        // --- CORREÇÃO: Atualiza o ID aqui também ---
        _userId = await _authService.userId; 
        _userNivel = await _authService.userNivel;
        _email = await _authService.userEmail;
        _nome = await _authService.userName;
      }
      notifyListeners();
      return success;
    } on ApiException catch (e) {
      _isLoading = false;
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Foto de perfil (do servidor ou guardada neste navegador).
  FotoPerfil _foto = const FotoPerfil();
  FotoPerfil get foto => _foto;

  /// Lê a foto guardada neste navegador para o usuário logado.
  Future<void> carregarFoto() async {
    final id = _userId ?? await _authService.userId;
    if (id == null) return;
    final bytes = await FotoPerfilService.instance.local(id);
    if (bytes != null && _foto.url == null) {
      _foto = FotoPerfil(bytes: bytes);
      notifyListeners();
    }
  }

  /// Troca a foto mostrada no perfil e no menu.
  void definirFoto(FotoPerfil foto) {
    _foto = foto;
    notifyListeners();
  }

  /// Atualiza nome e e-mail depois que o usuário edita o próprio perfil.
  Future<void> atualizarPerfil({String? nome, String? email}) async {
    await _authService.atualizarDadosLocais(nome: nome, email: email);
    if (nome != null) _nome = nome;
    if (email != null) _email = email;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _userId = null; // Limpa o ID
    _userNivel = null;
    _email = null; 
    _nome = null;
    _foto = const FotoPerfil();
    notifyListeners();
  }
}