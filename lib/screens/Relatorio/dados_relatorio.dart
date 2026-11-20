import 'package:fabrica_software_app/models/enums.dart';
import 'package:fabrica_software_app/models/projeto.dart';
import 'package:fabrica_software_app/models/recurso_projeto.dart';
import 'package:fabrica_software_app/models/teste.dart';
import 'package:fabrica_software_app/models/treinamento.dart';
import 'package:fabrica_software_app/services/projeto_service.dart';
import 'package:fabrica_software_app/services/recurso_projeto_service.dart';
import 'package:fabrica_software_app/services/teste_service.dart';
import 'package:fabrica_software_app/services/treinamento_service.dart';
import 'package:flutter/foundation.dart';

// =====================================================================
// Dados da tela de Relatórios. O back-end só tem um resumo fixo
// (/relatorios/dashboard, sem filtros), então os números são calculados
// aqui a partir das listas que a API já entrega: projetos, testes,
// treinamentos e alocações de recursos. Assim todos respeitam os filtros.
// =====================================================================

/// Atalhos de período da barra de ferramentas.
enum PeriodoRapido {
  dias30('30 dias'),
  meses3('3 meses'),
  meses12('12 meses'),
  tudo('Tudo'),
  personalizado('Personalizado');

  const PeriodoRapido(this.rotulo);
  final String rotulo;
}

const statusProjeto = ['Em processo', 'Atrasado', 'Concluído'];

const rotulosSituacaoTeste = {
  'pendente': 'Pendente',
  'em_progresso': 'Em execução',
  'concluido': 'Concluído',
  'falha': 'Falha',
};

/// Um nome só por tipo, com qualquer grafia ("MOBILE", "mobile" e
/// "Mobile" viram "Mobile"; siglas curtas ficam em maiúsculas: "API").
String? rotuloTipo(String? tipo) {
  final t = (tipo ?? '').trim();
  if (t.isEmpty) return null;
  if (t.length <= 3) return t.toUpperCase();
  return t[0].toUpperCase() + t.substring(1).toLowerCase();
}

String rotuloComplexidade(ComplexidadeProjeto? c) => switch (c) {
      ComplexidadeProjeto.baixa => 'Baixa',
      ComplexidadeProjeto.media => 'Média',
      ComplexidadeProjeto.alta => 'Alta',
      null => 'Não informada',
    };

class FiltrosRelatorio {
  const FiltrosRelatorio({
    this.periodo = PeriodoRapido.tudo,
    this.inicio,
    this.fim,
    this.status = const {},
    this.clientes = const {},
    this.complexidades = const {},
    this.tipos = const {},
  });

  final PeriodoRapido periodo;

  /// Só usados no período personalizado.
  final DateTime? inicio;
  final DateTime? fim;

  final Set<String> status;
  final Set<String> clientes;
  final Set<String> complexidades;
  final Set<String> tipos;

  /// Filtros do painel em uso (o período rápido fica de fora).
  int get ativos =>
      (periodo == PeriodoRapido.personalizado ? 1 : 0) +
      status.length +
      clientes.length +
      complexidades.length +
      tipos.length;

  FiltrosRelatorio copiar({
    PeriodoRapido? periodo,
    DateTime? inicio,
    DateTime? fim,
    Set<String>? status,
    Set<String>? clientes,
    Set<String>? complexidades,
    Set<String>? tipos,
  }) =>
      FiltrosRelatorio(
        periodo: periodo ?? this.periodo,
        inicio: inicio ?? this.inicio,
        fim: fim ?? this.fim,
        status: status ?? this.status,
        clientes: clientes ?? this.clientes,
        complexidades: complexidades ?? this.complexidades,
        tipos: tipos ?? this.tipos,
      );

  /// Intervalo de datas do período (null = sem limite).
  (DateTime?, DateTime?) get intervalo {
    final hoje = DateTime.now();
    final fimHoje = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
    return switch (periodo) {
      PeriodoRapido.dias30 => (hoje.subtract(const Duration(days: 30)), fimHoje),
      PeriodoRapido.meses3 => (DateTime(hoje.year, hoje.month - 3, hoje.day), fimHoje),
      PeriodoRapido.meses12 => (DateTime(hoje.year - 1, hoje.month, hoje.day), fimHoje),
      PeriodoRapido.tudo => (null, null),
      PeriodoRapido.personalizado => (
          inicio,
          fim == null ? null : DateTime(fim!.year, fim!.month, fim!.day, 23, 59, 59)
        ),
    };
  }
}

/// Um ponto de gráfico: rótulo e valor.
class ItemGrafico {
  const ItemGrafico(this.rotulo, this.valor, {this.detalhe});
  final String rotulo;
  final double valor;
  final String? detalhe;
}

class DadosRelatorioProvider extends ChangeNotifier {
  final _projetoService = ProjetoService();
  final _testeService = TesteService();
  final _treinamentoService = TreinamentoService();
  final _recursoService = RecursoProjetoService();

  bool carregando = false;
  String? erro;

  /// Partes que não vieram (a tela mostra o resto e avisa).
  final List<String> indisponiveis = [];

  List<Projeto> _projetos = [];
  List<Teste> _testes = [];
  List<Treinamento> _treinamentos = [];
  List<RecursoProjeto> _alocacoes = [];

  FiltrosRelatorio filtros = const FiltrosRelatorio();
  String busca = '';

  bool get temDados => _projetos.isNotEmpty;

  Future<void> carregar() async {
    carregando = true;
    erro = null;
    indisponiveis.clear();
    notifyListeners();

    Future<List<T>> pegar<T>(String nome, Future<List<T>> Function() f) async {
      try {
        return await f();
      } catch (_) {
        indisponiveis.add(nome);
        return <T>[];
      }
    }

    try {
      _projetos = await _projetoService.getProjetos();
    } catch (e) {
      erro = e.toString();
    }
    final resultados = await Future.wait([
      pegar('testes', _testeService.getTestes),
      pegar('treinamentos', _treinamentoService.getTreinamentos),
      pegar('recursos', _recursoService.getRecursosProjeto),
    ]);
    _testes = resultados[0] as List<Teste>;
    _treinamentos = resultados[1] as List<Treinamento>;
    _alocacoes = resultados[2] as List<RecursoProjeto>;

    carregando = false;
    notifyListeners();
  }

  void aplicarFiltros(FiltrosRelatorio novos) {
    filtros = novos;
    notifyListeners();
  }

  void mudarPeriodo(PeriodoRapido periodo) {
    filtros = filtros.copiar(periodo: periodo);
    notifyListeners();
  }

  void buscar(String texto) {
    busca = texto;
    notifyListeners();
  }

  // ---------------- Opções dos filtros ----------------

  List<String> _distintos(Iterable<String?> valores) {
    final s = valores
        .whereType<String>()
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return s;
  }

  List<String> get opcoesClientes => _distintos(_projetos.map((p) => p.clienteNome));
  List<String> get opcoesTipos => _distintos(_projetos.map((p) => rotuloTipo(p.tipo)));

  // ---------------- Filtragem ----------------

  static String _semAcento(String texto) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const para = 'aaaaaeeeeiiiiooooouuuucn';
    final saida = StringBuffer();
    for (final c in texto.toLowerCase().split('')) {
      final i = de.indexOf(c);
      saida.write(i >= 0 ? para[i] : c);
    }
    return saida.toString();
  }

  /// Data que posiciona o projeto no tempo (início; sem início, criação).
  static DateTime? dataDo(Projeto p) => p.dataInicio ?? p.dataCriacao;

  bool _noPeriodo(DateTime? data) {
    final (inicio, fim) = filtros.intervalo;
    if (inicio == null && fim == null) return true;
    if (data == null) return false;
    if (inicio != null && data.isBefore(inicio)) return false;
    if (fim != null && data.isAfter(fim)) return false;
    return true;
  }

  List<Projeto> get projetos {
    final termo = _semAcento(busca.trim());
    final f = filtros;
    return _projetos.where((p) {
      if (termo.isNotEmpty &&
          !_semAcento('${p.nomeProjeto} ${p.clienteNome ?? ''} ${p.tipo ?? ''}')
              .contains(termo)) {
        return false;
      }
      if (f.status.isNotEmpty && !f.status.contains(p.statusCalculado)) return false;
      if (f.clientes.isNotEmpty && !f.clientes.contains(p.clienteNome?.trim())) {
        return false;
      }
      if (f.complexidades.isNotEmpty &&
          !f.complexidades.contains(rotuloComplexidade(p.complexidade))) {
        return false;
      }
      if (f.tipos.isNotEmpty && !f.tipos.contains(rotuloTipo(p.tipo))) return false;
      return _noPeriodo(dataDo(p));
    }).toList()
      ..sort((a, b) => (dataDo(b) ?? DateTime(1900)).compareTo(dataDo(a) ?? DateTime(1900)));
  }

  Set<int> get _ids => {for (final p in projetos) if (p.id != null) p.id!};

  List<Teste> get testes {
    final ids = _ids;
    return _testes.where((t) => ids.contains(t.projetoId)).toList();
  }

  List<Treinamento> get treinamentos {
    final ids = _ids;
    return _treinamentos.where((t) => ids.contains(t.projetoId)).toList();
  }

  List<RecursoProjeto> get alocacoes {
    final ids = _ids;
    return _alocacoes.where((a) => ids.contains(a.projetoId)).toList();
  }

  // ---------------- Números ----------------

  double get orcamentoTotal =>
      projetos.fold(0, (s, p) => s + (p.orcamentoEstimado ?? 0));

  Map<String, int> get porStatus {
    final m = {for (final s in statusProjeto) s: 0};
    for (final p in projetos) {
      m[p.statusCalculado] = (m[p.statusCalculado] ?? 0) + 1;
    }
    return m;
  }

  Map<String, int> get porComplexidade {
    final m = <String, int>{'Baixa': 0, 'Média': 0, 'Alta': 0};
    for (final p in projetos) {
      if (p.complexidade == null) continue;
      final r = rotuloComplexidade(p.complexidade);
      m[r] = (m[r] ?? 0) + 1;
    }
    return m;
  }

  /// Custo do vínculo com quantidade e cobrança (por hora: dias × 8 h ×
  /// valor, a mesma conta do back-end; por mês; valor único).
  static double custoDe(RecursoProjeto a) => a.custoEstimado();

  double get custoRecursos => alocacoes.fold(0, (s, a) => s + custoDe(a));

  /// Custo de recursos dos projetos que mais gastam.
  List<ItemGrafico> custoPorProjeto({int limite = 5}) {
    final nomes = {for (final p in projetos) p.id: p.nomeProjeto};
    final soma = <int, double>{};
    for (final a in alocacoes) {
      soma[a.projetoId] = (soma[a.projetoId] ?? 0) + custoDe(a);
    }
    final itens = soma.entries
        .where((e) => e.value > 0)
        .map((e) => ItemGrafico(nomes[e.key] ?? 'Projeto ${e.key}', e.value))
        .toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
    return itens.take(limite).toList();
  }

  List<ItemGrafico> orcamentoPorCliente({int limite = 6}) {
    final soma = <String, double>{};
    for (final p in projetos) {
      final c = (p.clienteNome ?? '').trim().isEmpty ? 'Sem cliente' : p.clienteNome!.trim();
      soma[c] = (soma[c] ?? 0) + (p.orcamentoEstimado ?? 0);
    }
    final itens = soma.entries.map((e) => ItemGrafico(e.key, e.value)).toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
    return itens.take(limite).toList();
  }

  static const _meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

  /// Contagem por mês (até 12 meses) ou por ano, quando o período é maior.
  /// Meses sem nada aparecem com zero, para a linha do tempo não pular.
  List<ItemGrafico> linhaDoTempo(Iterable<DateTime?> datas) {
    final lista = datas.whereType<DateTime>().toList();
    var (inicio, fim) = filtros.intervalo;
    fim ??= DateTime.now();
    if (inicio == null) {
      if (lista.isEmpty) return [];
      inicio = lista.reduce((a, b) => a.isBefore(b) ? a : b);
    }
    final meses = (fim.year - inicio.year) * 12 + fim.month - inicio.month + 1;

    if (meses > 12) {
      final m = <int, int>{};
      for (var a = inicio.year; a <= fim.year; a++) {
        m[a] = 0;
      }
      for (final d in lista) {
        if (m.containsKey(d.year)) m[d.year] = m[d.year]! + 1;
      }
      final anos = m.keys.toList()..sort();
      return [for (final a in anos.skip((anos.length - 8).clamp(0, 100))) ItemGrafico('$a', m[a]!.toDouble())];
    }

    final itens = <ItemGrafico>[];
    for (var i = 0; i < meses; i++) {
      final ref = DateTime(inicio.year, inicio.month + i);
      final n = lista.where((d) => d.year == ref.year && d.month == ref.month).length;
      itens.add(ItemGrafico(_meses[ref.month - 1], n.toDouble(),
          detalhe: '${_meses[ref.month - 1]}/${ref.year}'));
    }
    return itens;
  }

  bool get linhaPorAno {
    final itens = linhaDoTempo(projetos.map(dataDo));
    return itens.isNotEmpty && itens.first.detalhe == null;
  }

  // Testes
  Map<String, int> get testesPorSituacao {
    final m = {for (final k in rotulosSituacaoTeste.keys) k: 0};
    for (final t in testes) {
      m[t.situacao] = (m[t.situacao] ?? 0) + 1;
    }
    return m;
  }

  /// % de testes concluídos (null sem testes).
  double? get taxaTestes {
    final total = testes.length;
    if (total == 0) return null;
    return (testesPorSituacao['concluido'] ?? 0) / total * 100;
  }

  // Treinamentos
  bool treinamentoConcluido(Treinamento t) =>
      t.dataTermino != null && t.dataTermino!.isBefore(DateTime.now());

  int get treinamentosConcluidos => treinamentos.where(treinamentoConcluido).length;

  int get horasTreinamento =>
      treinamentos.fold(0, (s, t) => s + (t.duracaoHoras ?? 0));

  String nomeDoProjeto(int id) =>
      _projetos.firstWhere((p) => p.id == id, orElse: () => Projeto(nomeProjeto: 'Projeto $id', clienteId: 0, criadoPorId: 0)).nomeProjeto;
}
