import 'package:shared_preferences/shared_preferences.dart';
import 'package:fabrica_software_app/config/projeto_dto.dart';
import 'package:fabrica_software_app/services/projeto_service.dart';
import 'package:flutter/foundation.dart';
import '../models/projeto.dart';
import '../services/api_service.dart';
import '../services/base_api_service.dart';

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

/// Ordem da lista: padrão (atrasados, em processo e concluídos, pela data
/// final), A a Z ou Z a A pelo nome. O botão de ordenar passa por elas.
enum OrdemProjetos { padrao, az, za }

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

      // Tipo do projeto (o modelo não entra: é outra informação).
      if (f.tipo != null) {
        final tipo = (projeto.tipo ?? '').trim();
        final igual = f.tipo == tipoOutro
            ? ehTipoOutro(tipo)
            : tipo.toUpperCase() == f.tipo!.toUpperCase();
        if (!igual) return false;
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

  /// Tipos de projeto de criar, editar e filtrar: os padrão, mais os
  /// personalizados já salvos em algum projeto (escritos em "Outro" ou
  /// antigos, como AI e DATA), e "Outro" no fim. O tipo fica gravado no
  /// projeto, então um tipo novo passa a aparecer para todos depois de salvo.
  List<String> get tiposDisponiveis {
    final vistos = {for (final t in tiposProjeto) t.toUpperCase()};
    final personalizados = <String>[];
    for (final p in _projetos) {
      final tipo = (p.tipo ?? '').trim();
      if (tipo.isEmpty || ehTipoOutro(tipo)) continue;
      // Sem repetir o mesmo tipo com outra caixa (Chatbot / CHATBOT).
      if (vistos.add(tipo.toUpperCase())) personalizados.add(tipo);
    }
    personalizados.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [...tiposProjeto, ...personalizados, tipoOutro];
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

  /// Projetos já carregados (para quem precisa contar, como Clientes).
  bool get projetosCarregados => _projetos.isNotEmpty;

  /// Quantos projetos o cliente tem (sem filtro).
  int projetosDoCliente(int? clienteId) =>
      clienteId == null ? 0 : _projetos.where((p) => p.clienteId == clienteId).length;

  /// Pessoas do projeto (para os avatares do card).
  List<MembroProjeto> membrosDoProjeto(int? projetoId) {
    final ids = _membrosPorProjeto['$projetoId'];
    if (ids == null) return const [];
    return [
      for (final m in _membros)
        if (ids.contains(m.id)) m
    ];
  }

  String nomeDoMembro(String id) => _membros
      .firstWhere((m) => m.id == id, orElse: () => (id: id, nome: id))
      .nome;

  // Ações
  Future<void> carregarProjetos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _projetos = await _service
          .getProjetos(); // Verifique o nome do método no seu Service
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    _carregarMembros();
    _carregarFixados();
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
      _membros = [for (final e in nomes.entries) (id: e.key, nome: e.value)]
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      notifyListeners();
    } catch (e) {
      debugPrint('Filtro de membros indisponível: $e');
    }
  }

  // ---------------------------------------------------------------- ordem

  OrdemProjetos _ordem = OrdemProjetos.padrao;
  OrdemProjetos get ordem => _ordem;

  /// padrão -> A a Z -> Z a A -> padrão.
  void proximaOrdem() {
    _ordem =
        OrdemProjetos.values[(_ordem.index + 1) % OrdemProjetos.values.length];
    notifyListeners();
  }

  /// Projetos filtrados, na ordem escolhida, com os fixados sempre no topo.
  List<Projeto> get projetosOrdenados {
    final lista = List<Projeto>.of(projetos);
    int comparar(Projeto a, Projeto b) {
      final fa = estaFixado(a.id), fb = estaFixado(b.id);
      if (fa != fb) return fa ? -1 : 1;
      switch (_ordem) {
        case OrdemProjetos.az:
          return _nome(a).compareTo(_nome(b));
        case OrdemProjetos.za:
          return _nome(b).compareTo(_nome(a));
        case OrdemProjetos.padrao:
          final porStatus = _pesoStatus(a).compareTo(_pesoStatus(b));
          if (porStatus != 0) return porStatus;
          final porData = _compararData(a, b);
          return porData != 0 ? porData : _nome(a).compareTo(_nome(b));
      }
    }

    lista.sort(comparar);
    return lista;
  }

  static int _pesoStatus(Projeto p) => switch (p.statusCalculado) {
        'Atrasado' => 0,
        'Em processo' => 1,
        _ => 2, // Concluído
      };

  /// Atrasados: o mais atrasado primeiro; em processo: o que termina antes
  /// primeiro; concluídos: o concluído mais recente primeiro. Sem data, no fim.
  static int _compararData(Projeto a, Projeto b) {
    final concluido = a.statusCalculado == 'Concluído';
    final da = concluido ? a.dataFinal : a.dataFinalPrevisto;
    final db = concluido ? b.dataFinal : b.dataFinalPrevisto;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return concluido ? db.compareTo(da) : da.compareTo(db);
  }

  /// Nome para ordenar: sem acento e sem diferença de maiúsculas
  /// ("Ética" fica junto do "E", e não depois do "Z").
  static String _nome(Projeto p) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const para = 'aaaaaeeeeiiiiooooouuuucn';
    final texto = p.nomeProjeto.trim().toLowerCase();
    final saida = StringBuffer();
    for (final c in texto.split('')) {
      final i = de.indexOf(c);
      saida.write(i >= 0 ? para[i] : c);
    }
    return saida.toString();
  }

  // -------------------------------------------------- projetos fixados

  static const _chaveFixados = 'projetos_fixados';

  /// Ids dos projetos fixados no topo. Ficam só neste navegador/computador
  /// (preferências locais), sem passar pelo back-end.
  Set<String> _fixados = {};
  bool _fixadosCarregados = false;

  bool estaFixado(int? id) => _fixados.contains('$id');

  Future<void> alternarFixado(int? id) async {
    if (id == null) return;
    _fixados = {..._fixados};
    if (!_fixados.remove('$id')) _fixados.add('$id');
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_chaveFixados, _fixados.toList());
    } catch (e) {
      debugPrint('Não foi possível salvar os projetos fixados: $e');
    }
  }

  Future<void> _carregarFixados() async {
    if (_fixadosCarregados) return;
    _fixadosCarregados = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _fixados = {...?prefs.getStringList(_chaveFixados)};
      notifyListeners();
    } catch (e) {
      debugPrint('Não foi possível ler os projetos fixados: $e');
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
      // Não usa `_error`: ele é o erro de carregamento e trocaria a lista
      // toda pela mensagem. Quem chama mostra o aviso.
      if (e is ApiException && e.message.trim().isNotEmpty) rethrow;
      throw ApiException('Não foi possível excluir o projeto.');
    }
  }
}
