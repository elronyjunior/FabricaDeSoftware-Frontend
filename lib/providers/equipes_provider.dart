import 'package:fabrica_software_app/services/contribuidor_projeto_service.dart';
import 'package:flutter/material.dart';
import '../models/projeto.dart';
import '../models/contribuidor.dart';
import '../models/contribuidor_projeto.dart';
import '../models/usuario.dart';
import '../services/projeto_service.dart';
import '../services/contribuidor_service.dart';
import '../services/usuario_service.dart';

/// Membro de uma equipe, com o nome do usuário quando há um.
class MembroEquipe {
  const MembroEquipe({required this.contribuidor, this.usuario});
  final Contribuidor contribuidor;
  final Usuario? usuario;

  String get nome => usuario?.nome ?? contribuidor.nome;
  String get email => usuario?.email ?? contribuidor.email;
}

/// Equipes dos projetos.
///
/// As pessoas são os usuários de "Gestão de usuários". No banco, porém, a
/// equipe (contribuidores_projeto) aponta para a tabela `contribuidores`:
/// por isso cada usuário é ligado ao contribuidor de mesmo e-mail (único nas
/// duas tabelas), criado na hora se ainda não existir.
class EquipesProvider with ChangeNotifier {
  final _projetoService = ProjetoService();
  final _contribuidorService = ContribuidorService();
  final _usuarioService = UsuarioService();
  final _vinculoService = ContribuidoresProjetoService.instance;

  bool _isLoading = false;
  String? _error;

  List<Projeto> _projetos = [];
  List<Usuario> _usuarios = [];
  List<Contribuidor> _contribuidores = [];
  List<ContribuidorProjeto> _vinculos = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Projeto> get projetos => _projetos;

  /// Pessoas que podem entrar nas equipes (os usuários do sistema).
  List<Usuario> get pessoas => _usuarios;

  Future<void> carregarDados() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _projetoService.getProjetos(),
        _usuarioService.getUsuarios(),
        _contribuidorService.getContribuidores(),
        _vinculoService.listarContribuidoresProjeto(),
      ]);

      _projetos = results[0] as List<Projeto>;
      _usuarios = (results[1] as List<Usuario>)
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      _contribuidores = results[2] as List<Contribuidor>;
      _vinculos = results[3] as List<ContribuidorProjeto>;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static String _chave(String email) => email.trim().toLowerCase();

  Usuario? _usuarioDoEmail(String email) {
    final chave = _chave(email);
    for (final u in _usuarios) {
      if (_chave(u.email) == chave) return u;
    }
    return null;
  }

  Contribuidor? _contribuidorDoEmail(String email) {
    final chave = _chave(email);
    for (final c in _contribuidores) {
      if (_chave(c.email) == chave) return c;
    }
    return null;
  }

  /// Equipe do projeto, com o nome do usuário quando há um.
  List<MembroEquipe> membrosDoProjeto(int projetoId) {
    final ids = {
      for (final v in _vinculos)
        if (v.projetoId == projetoId) v.contribuidorId
    };
    return [
      for (final c in _contribuidores)
        if (ids.contains(c.id))
          MembroEquipe(contribuidor: c, usuario: _usuarioDoEmail(c.email)),
    ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  }

  bool usuarioNoProjeto(int projetoId, Usuario usuario) {
    final c = _contribuidorDoEmail(usuario.email);
    if (c == null) return false;
    return _vinculos
        .any((v) => v.projetoId == projetoId && v.contribuidorId == c.id);
  }

  /// Em quantos projetos o usuário está.
  int projetosDoUsuario(Usuario usuario) {
    final c = _contribuidorDoEmail(usuario.email);
    if (c == null) return 0;
    return _vinculos.where((v) => v.contribuidorId == c.id).length;
  }

  // As ações devolvem a mensagem de erro (ou null se deu certo): a tela avisa
  // e continua mostrando as listas.

  /// Coloca o usuário na equipe do projeto (cria o contribuidor dele antes,
  /// se ainda não existir).
  Future<String?> adicionarUsuario(int projetoId, Usuario usuario) async {
    if (usuarioNoProjeto(projetoId, usuario)) return null;
    try {
      var contribuidor = _contribuidorDoEmail(usuario.email);
      if (contribuidor == null) {
        contribuidor = await _contribuidorService.createContribuidor(
          Contribuidor(
            nome: usuario.nome,
            email: usuario.email,
            cargo: usuario.nivel,
          ),
        );
        _contribuidores.add(contribuidor);
      }
      final vinculo = await _vinculoService.adicionarContribuidorProjeto({
        "projeto_id": projetoId,
        "contribuidor_id": contribuidor.id,
        "data_inicio": DateTime.now().toIso8601String(),
      });
      _vinculos.add(vinculo);
      notifyListeners();
      return null;
    } catch (e) {
      return "Não foi possível adicionar à equipe: $e";
    }
  }

  Future<String?> removerMembro(int projetoId, int contribuidorId) async {
    try {
      await _vinculoService.removerVinculo(projetoId, contribuidorId);
      _vinculos.removeWhere(
          (v) => v.projetoId == projetoId && v.contribuidorId == contribuidorId);
      notifyListeners();
      return null;
    } catch (e) {
      return "Não foi possível tirar da equipe: $e";
    }
  }
}
