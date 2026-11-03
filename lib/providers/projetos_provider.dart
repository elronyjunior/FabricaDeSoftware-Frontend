import 'package:fabrica_software_app/services/projeto_service.dart';
import 'package:flutter/foundation.dart';
import '../models/projeto.dart';
import '../services/projetos_service.dart';
import '../services/api_service.dart';

/// Filtros do popover "Filtrar projetos". Vazio = sem filtro.
class FiltrosProjeto {
  const FiltrosProjeto({
    this.status = const {},
    this.conclusaoAte,
    this.tipo,
    this.cliente = '',
    this.membros = const {},
  });

  /// Status calculados aceitos (vários de uma vez).
  final Set<String> status;

  /// Projetos que terminam (ou devem terminar) até esta data.
  final DateTime? conclusaoAte;

  /// Tipo mostrado no card; nulo = todos.
  final String? tipo;

  /// Parte do nome do cliente.
  final String cliente;

  /// Ids dos contribuidores: o projeto precisa ter todos eles.
  final Set<String> membros;

  static const vazio = FiltrosProjeto();

  /// Quantos filtros estão ligados (contador do botão "Filtro").
  int get ativos =>
      (status.isNotEmpty ? 1 : 0) +
      (conclusaoAte != null ? 1 : 0) +
      (tipo != null ? 1 : 0) +
      (cliente.trim().isNotEmpty ? 1 : 0) +
      (membros.isNotEmpty ? 1 : 0);
}

/// Contribuidor que aparece em algum projeto (opções do filtro de membros).
typedef MembroProjeto = ({String id, String nome});

class ProjetosProvider with ChangeNotifier {
  final _service = ProjetoService();

  bool _isLoading = false;
  String? _error;
  List<Projeto> _projetos = []; // Lista original (Cache)

  // Variáveis de Filtro
  String _filtroNome = '';
  FiltrosProjeto _filtros = FiltrosProjeto.vazio;

  /// Membros de cada projeto (id do projeto -> ids dos contribuidores).
  Map<String, Set<String>> _membrosPorProjeto = {};
  List<MembroProjeto> _membros = [];

  // Getters
  bool get isLoading => _isLoading;
  String get filtroNome => _filtroNome;
  FiltrosProjeto get filtros => _filtros;
  String? get error => _error;

  // Getter Mágico: Retorna a lista já filtrada
  List<Projeto> get projetos {
    if (_projetos.isEmpty) return [];
    final f = _filtros;
    final nome = _filtroNome.toLowerCase();
    final cliente = f.cliente.trim().toLowerCase();
    // "Até 09/12" inclui o dia inteiro.
    final limite = f.conclusaoAte == null
        ? null
        : DateTime(f.conclusaoAte!.year, f.conclusaoAte!.month,
            f.conclusaoAte!.day, 23, 59, 59);

    return _projetos.where((projeto) {
      if (!projeto.nomeProjeto.toLowerCase().contains(nome)) return false;

      if (cliente.isNotEmpty &&
          !(projeto.clienteNome ?? '').toLowerCase().contains(cliente)) {
        return false;
      }

      // Tipo: o mesmo mostrado no card (tipo, ou o modelo quando vazio).
      if (f.tipo != null && _tipoDe(projeto) != f.tipo!.toUpperCase()) {
        return false;
      }

      if (f.status.isNotEmpty && !f.status.contains(projeto.statusCalculado)) {
        return false;
      }

      if (limite != null) {
        final fim = projeto.dataFinal ?? projeto.dataFinalPrevisto;
        if (fim == null || fim.isAfter(limite)) return false;
      }

      if (f.membros.isNotEmpty) {
        final doProjeto = _membrosPorProjeto['${projeto.id}'] ?? const {};
        if (!doProjeto.containsAll(f.membros)) return false;
      }

      return true;
    }).toList();
  }

  static String _tipoDe(Projeto p) {
    final tipo = (p.tipo ?? '').trim();
    return (tipo.isNotEmpty ? tipo : (p.modeloProjeto ?? '')).toUpperCase();
  }

  /// Tipos que existem nos projetos carregados (opções do filtro).
  List<String> get tiposDisponiveis {
    final tipos = {
      for (final p in _projetos)
        if (_tipoDe(p).isNotEmpty) _tipoDe(p)
    }.toList()
      ..sort();
    return tipos;
  }

  /// Clientes dos projetos carregados (sugestões do filtro).
  List<String> get clientesDisponiveis {
    final nomes = {
      for (final p in _projetos)
        if ((p.clienteNome ?? '').trim().isNotEmpty) p.clienteNome!.trim()
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return nomes;
  }

  /// Pessoas que participam de algum projeto (sugestões do filtro).
  List<MembroProjeto> get membrosDisponiveis => _membros;

  String nomeDoMembro(String id) =>
      _membros.firstWhere((m) => m.id == id, orElse: () => (id: id, nome: id))
          .nome;

  // Ações
  Future<void> carregarProjetos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _projetos = await _service.getProjetos(); // Verifique o nome do método no seu Service
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    _carregarMembros();
  }

  /// Membros de cada projeto, para o filtro "Membros". Se falhar, o filtro
  /// só fica sem sugestões.
  Future<void> _carregarMembros() async {
    try {
      final linhas = await ApiService.getContribuidoresProjetos();
      final porProjeto = <String, Set<String>>{};
      final nomes = <String, String>{};
      for (final l in linhas) {
        final projeto = '${l['projeto_id']}';
        final pessoa = '${l['contribuidor_id']}';
        porProjeto.putIfAbsent(projeto, () => {}).add(pessoa);
        nomes[pessoa] = '${l['contribuidor_nome'] ?? pessoa}';
      }
      _membrosPorProjeto = porProjeto;
      _membros = [
        for (final e in nomes.entries) (id: e.key, nome: e.value)
      ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      notifyListeners();
    } catch (e) {
      debugPrint('Filtro de membros indisponível: $e');
    }
  }

  void aplicarFiltros(FiltrosProjeto filtros) {
    _filtros = filtros;
    notifyListeners();
  }

  // Métodos para atualizar os filtros via Interface
  void setFiltroNome(String valor) {
    _filtroNome = valor;
    notifyListeners(); // Avisa a tela para redesenhar a lista
  }

  void setFiltroCliente(String valor) => aplicarFiltros(FiltrosProjeto(
        status: _filtros.status,
        conclusaoAte: _filtros.conclusaoAte,
        tipo: _filtros.tipo,
        cliente: valor,
        membros: _filtros.membros,
      ));

  void limparFiltros() {
    _filtroNome = '';
    _filtros = FiltrosProjeto.vazio;
    notifyListeners();
  }

  // No arquivo providers/projetos_provider.dart

Future<void> excluirProjeto(int id) async {
  try {
    await _service.deleteProjeto(id); // Chama a API
    
    // Remove da lista localmente para não precisar recarregar tudo
    _projetos.removeWhere((p) => p.id == id);
    
    notifyListeners(); // Atualiza a tela
  } catch (e) {
    _error = "Erro ao excluir: $e";
    notifyListeners();
  }
}
}