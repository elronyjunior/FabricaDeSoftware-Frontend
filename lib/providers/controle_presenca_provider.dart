import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fabrica_software_app/config/api_config.dart';
import 'package:fabrica_software_app/services/auth_service.dart';

/// Planilha de presença de um treinamento.
///
/// - As marcações são salvas sozinhas, pouco depois da última mudança.
/// - Só a primeira carga troca a tela pelo carregando ([isLoading]). As
///   ações depois disso (adicionar dia, aluno, lista) deixam a lista na tela
///   e mostram o andamento em [ocupado] / [andamento].
class ControlePresencaProvider with ChangeNotifier {
  /// Espera depois da última marcação antes de salvar (junta cliques
  /// seguidos num envio só).
  static const esperaSalvar = Duration(milliseconds: 700);

  bool _isLoading = false;
  bool _ocupado = false;
  String? _andamento;
  String? _error;

  String? _sheetId;
  List<String> _headersDias = [];
  List<dynamic> _alunos = [];

  final Map<String, Map<String, dynamic>> _mudancasLocais = {};
  Timer? _timerSalvar;
  Future<bool>? _salvando;
  String? _erroSalvar;
  DateTime? _salvoEm;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _timerSalvar?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Só na primeira carga (ainda não há lista para mostrar).
  bool get isLoading => _isLoading;

  /// Uma ação que muda a planilha está em andamento (a lista continua na
  /// tela, mas não deve ser mexida até terminar).
  bool get ocupado => _ocupado;

  /// Texto do andamento ("Adicionando 3 de 15…").
  String? get andamento => _andamento;

  String? get error => _error;

  // Erro da última ação (adicionar/remover). Fica separado de [error]
  // porque [error] troca a tela pela mensagem.
  String? _ultimoErro;
  String? get ultimoErro => _ultimoErro;

  bool get isSaving => _salvando != null;
  String? get erroSalvar => _erroSalvar;
  DateTime? get salvoEm => _salvoEm;

  List<String> get headersDias => _headersDias;
  List<dynamic> get alunos => _alunos;
  bool get temMudancasPendentes => _mudancasLocais.isNotEmpty;

  /// Carrega a planilha. Com [silencioso] (recarga depois de uma ação), a
  /// lista atual fica na tela e uma falha não a troca pelo erro.
  Future<void> carregarDados(int treinamentoId,
      {bool silencioso = false}) async {
    if (!silencioso) {
      _isLoading = true;
      _error = null;
      _mudancasLocais.clear();
      notifyListeners();
    }

    try {
      final token = await AuthService.instance.token;
      final url = Uri.parse(
          '${ApiConfig.baseUrl}/treinamentos/$treinamentoId/presenca');
      final response =
          await http.get(url, headers: ApiConfig.getAuthHeaders(token));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _sheetId = data['sheetId'];
        _headersDias = List<String>.from(data['headers']);
        _alunos = data['alunos'];
        _error = null;
      } else if (silencioso) {
        _ultimoErro =
            'Não foi possível atualizar a lista (status ${response.statusCode}).';
      } else {
        _error = "Erro ao carregar (Status ${response.statusCode})";
      }
    } catch (e) {
      if (silencioso) {
        _ultimoErro =
            'Não foi possível atualizar a lista. Verifique a conexão.';
      } else {
        _error = "Erro de conexão: $e";
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marca P, F ou "" (limpa) e agenda o salvamento.
  void setPresenca(int rowIndex, int diaIndex, String novoStatus) {
    final aluno = _alunos.firstWhere((a) => a['rowIndex'] == rowIndex);
    final diaKey = _headersDias[diaIndex];
    if ((aluno['presencas'][diaKey] ?? '') == novoStatus) return;

    aluno['presencas'][diaKey] = novoStatus;
    // Um mapa novo a cada mudança: ao salvar, só sai da fila o que não
    // mudou de novo enquanto o envio estava em andamento.
    _mudancasLocais['$rowIndex-$diaIndex'] = {
      "rowIndex": rowIndex,
      "diaIndex": diaIndex,
      "status": novoStatus,
    };
    _erroSalvar = null;
    _agendarSalvamento();
    notifyListeners();
  }

  void _agendarSalvamento() {
    _timerSalvar?.cancel();
    _timerSalvar = Timer(esperaSalvar, () {
      if (!_disposed) salvarAlteracoes();
    });
  }

  /// Salva agora o que estiver pendente (espera um envio em andamento).
  Future<bool> salvarAlteracoes() async {
    _timerSalvar?.cancel();
    while (_salvando != null) {
      await _salvando;
    }
    if (_mudancasLocais.isEmpty) return _erroSalvar == null;
    final envio = _enviar();
    _salvando = envio;
    notifyListeners();
    final ok = await envio;
    _salvando = null;
    notifyListeners();
    // Marcações feitas durante o envio: salva logo em seguida.
    if (ok && _mudancasLocais.isNotEmpty && !_disposed) _agendarSalvamento();
    return ok;
  }

  Future<bool> _enviar() async {
    final enviadas = Map.of(_mudancasLocais);
    try {
      final token = await AuthService.instance.token;
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/treinamentos/presenca/lote'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode(
            {"sheetId": _sheetId, "mudancas": enviadas.values.toList()}),
      );
      if (response.statusCode == 200) {
        enviadas.forEach((k, v) {
          if (identical(_mudancasLocais[k], v)) _mudancasLocais.remove(k);
        });
        _erroSalvar = null;
        _salvoEm = DateTime.now();
        return true;
      }
      _erroSalvar =
          'Não foi possível salvar a chamada (status ${response.statusCode}).';
      return false;
    } catch (_) {
      _erroSalvar = 'Não foi possível salvar a chamada. Verifique a conexão.';
      return false;
    }
  }

  // Adicionar/remover dia ou aluno muda a planilha e recarrega tudo, e as
  // mudanças locais são chaveadas por rowIndex/diaIndex — que mudam de
  // posição quando uma linha ou coluna entra/sai. Por isso as pendentes são
  // salvas ANTES; se o salvamento falhar, a ação é cancelada.
  Future<bool> _salvarPendentesAntes() async {
    if (_mudancasLocais.isEmpty && _salvando == null) return true;
    final ok = await salvarAlteracoes();
    if (!ok) _ultimoErro = _erroSalvar;
    return ok;
  }

  void _iniciar(String andamento) {
    _ocupado = true;
    _andamento = andamento;
    _ultimoErro = null;
    notifyListeners();
  }

  void _terminar() {
    _ocupado = false;
    _andamento = null;
    notifyListeners();
  }

  // Executa uma ação que altera a estrutura da planilha: salva as pendentes,
  // chama a API, confere o status e recarrega sem tirar a lista da tela.
  Future<bool> _alterarEstrutura(
    int treinamentoId,
    String andamento,
    Future<http.Response> Function(String? token) chamada,
    String mensagemErro,
  ) async {
    if (_ocupado) return false;
    _iniciar(andamento);
    if (!await _salvarPendentesAntes()) {
      _terminar();
      return false;
    }
    try {
      final token = await AuthService.instance.token;
      final response = await chamada(token);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _ultimoErro = '$mensagemErro (status ${response.statusCode}).';
        _terminar();
        return false;
      }
    } catch (e) {
      _ultimoErro = '$mensagemErro. Verifique a conexão.';
      _terminar();
      return false;
    }
    if (_disposed) return true;
    await carregarDados(treinamentoId, silencioso: true);
    _terminar();
    return _ultimoErro == null;
  }

  Map<String, String> _headersJson(String? token) {
    final headers = ApiConfig.getAuthHeaders(token);
    headers['Content-Type'] = 'application/json';
    return headers;
  }

  Future<bool> adicionarDia(int treinamentoId, String dataFormatada) {
    return _alterarEstrutura(
      treinamentoId,
      'Adicionando o dia $dataFormatada…',
      (token) => http.post(
        Uri.parse('${ApiConfig.baseUrl}/treinamentos/dia'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({"sheetId": _sheetId, "data": dataFormatada}),
      ),
      'Não foi possível adicionar o dia',
    );
  }

  Future<bool> adicionarAluno(int treinamentoId, String nome, String email) {
    return _alterarEstrutura(
      treinamentoId,
      'Adicionando $nome…',
      (token) => http.post(
        Uri.parse('${ApiConfig.baseUrl}/treinamentos/aluno'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({"sheetId": _sheetId, "nome": nome, "email": email}),
      ),
      'Não foi possível adicionar o aluno',
    );
  }

  /// Adiciona vários alunos (lista importada). O back só tem a rota de um
  /// aluno por vez, então vão um a um e a planilha é recarregada no fim.
  /// Devolve quantos falharam (-1 se nem começou).
  Future<int> adicionarAlunos(
    int treinamentoId,
    List<({String nome, String email})> novos,
  ) async {
    if (_ocupado) return -1;
    _iniciar('Adicionando 0 de ${novos.length}…');
    if (!await _salvarPendentesAntes()) {
      _terminar();
      return -1;
    }
    var falhas = 0;
    final token = await AuthService.instance.token;
    for (var i = 0; i < novos.length; i++) {
      if (_disposed) return falhas;
      _andamento = 'Adicionando ${i + 1} de ${novos.length}…';
      notifyListeners();
      try {
        final r = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/treinamentos/aluno'),
          headers: ApiConfig.getAuthHeaders(token),
          body: jsonEncode({
            "sheetId": _sheetId,
            "nome": novos[i].nome,
            "email": novos[i].email
          }),
        );
        if (r.statusCode < 200 || r.statusCode >= 300) falhas++;
      } catch (_) {
        falhas++;
      }
    }
    if (_disposed) return falhas;
    _andamento = 'Atualizando a lista…';
    notifyListeners();
    await carregarDados(treinamentoId, silencioso: true);
    if (falhas > 0) {
      _ultimoErro = falhas == novos.length
          ? 'Não foi possível adicionar os participantes.'
          : '$falhas de ${novos.length} participantes não foram adicionados.';
    }
    _terminar();
    return falhas;
  }

  /// Marca todos os alunos com o mesmo status no dia (P, F ou "" limpa).
  void marcarTodos(int diaIndex, String status) {
    for (final a in _alunos) {
      setPresenca(a['rowIndex'], diaIndex, status);
    }
  }

  Future<bool> removerDia(int treinamentoId, int index) {
    return _alterarEstrutura(
      treinamentoId,
      'Removendo o dia…',
      (token) => http.delete(
        Uri.parse('${ApiConfig.baseUrl}/treinamentos/dia')
            .replace(queryParameters: {
          'sheetId': _sheetId,
          'diaIndex': index.toString(),
        }),
        headers: _headersJson(token),
      ),
      'Não foi possível remover o dia',
    );
  }

  Future<bool> removerAluno(int treinamentoId, int rowIndex) {
    return _alterarEstrutura(
      treinamentoId,
      'Removendo o participante…',
      (token) => http.delete(
        Uri.parse('${ApiConfig.baseUrl}/treinamentos/aluno')
            .replace(queryParameters: {
          'sheetId': _sheetId,
          'rowIndex': rowIndex.toString(),
        }),
        headers: _headersJson(token),
      ),
      'Não foi possível remover o aluno',
    );
  }
}
