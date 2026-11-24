import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fabrica_software_app/config/api_config.dart';
import 'package:fabrica_software_app/services/auth_service.dart';

class ControlePresencaProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  
  String? _sheetId;
  List<String> _headersDias = [];
  List<dynamic> _alunos = [];
  
  final Map<String, dynamic> _mudancasLocais = {};

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  // Erro da última ação (salvar, adicionar/remover). Fica separado de
  // [error] porque [error] troca a tabela inteira pela mensagem — uma falha
  // ao salvar não pode esconder as presenças marcadas.
  String? _ultimoErro;
  String? get ultimoErro => _ultimoErro;
  List<String> get headersDias => _headersDias;
  List<dynamic> get alunos => _alunos;
  bool get temMudancasPendentes => _mudancasLocais.isNotEmpty;

  // Carregar Dados
  Future<void> carregarDados(int treinamentoId) async {
    _isLoading = true;
    _error = null;
    _mudancasLocais.clear();
    notifyListeners();

    try {
      final token = await AuthService.instance.token;
      final url = Uri.parse('${ApiConfig.baseUrl}/treinamentos/$treinamentoId/presenca');
      final response = await http.get(url, headers: ApiConfig.getAuthHeaders(token));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _sheetId = data['sheetId'];
        _headersDias = List<String>.from(data['headers']);
        _alunos = data['alunos'];
      } else {
        _error = "Erro ao carregar (Status ${response.statusCode})";
      }
    } catch (e) {
      _error = "Erro de conexão: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- CORREÇÃO AQUI: Lógica Direta ---
  void setPresenca(int rowIndex, int diaIndex, String novoStatus) {
    // 1. Atualiza visualmente na hora
    final aluno = _alunos.firstWhere((a) => a['rowIndex'] == rowIndex);
    String diaKey = _headersDias[diaIndex];
    
    // Se o status já é o mesmo, não faz nada (evita loop), a menos que seja para limpar
    if (aluno['presencas'][diaKey] == novoStatus && novoStatus != "") return;

    aluno['presencas'][diaKey] = novoStatus;

    // 2. Adiciona na fila de salvamento
    String key = "$rowIndex-$diaIndex";
    _mudancasLocais[key] = {
      "rowIndex": rowIndex,
      "diaIndex": diaIndex,
      "status": novoStatus
    };

    notifyListeners();
  }

  // Salvar
  Future<bool> salvarAlteracoes() async {
    if (_mudancasLocais.isEmpty) return true;
    _isSaving = true;
    _ultimoErro = null;
    notifyListeners();

    try {
      final token = await AuthService.instance.token;
      List<dynamic> listaMudancas = _mudancasLocais.values.toList();

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/treinamentos/presenca/lote'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({"sheetId": _sheetId, "mudancas": listaMudancas}),
      );

      if (response.statusCode == 200) {
        _mudancasLocais.clear();
        return true;
      }
      _ultimoErro = 'Não foi possível salvar a chamada (status ${response.statusCode}).';
      return false;
    } catch (e) {
      _ultimoErro = 'Não foi possível salvar a chamada. Verifique a conexão.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // Adicionar/remover dia ou aluno muda a planilha e recarrega tudo, e as
  // mudanças locais são chaveadas por rowIndex/diaIndex — que mudam de
  // posição quando uma linha ou coluna entra/sai. Reaplicar depois seria
  // arriscado (marcaria a presença no aluno/dia errado), então o mais seguro
  // é salvar as pendentes ANTES. Se o salvamento falhar, a ação é cancelada
  // e nada do que foi marcado se perde.
  Future<bool> _salvarPendentesAntes() async {
    if (_mudancasLocais.isEmpty) return true;
    return salvarAlteracoes();
  }

  // Executa uma ação que altera a estrutura da planilha: salva as pendentes,
  // chama a API, confere o status e recarrega. Retorna false com
  // [ultimoErro] preenchido em qualquer falha.
  Future<bool> _alterarEstrutura(
    int treinamentoId,
    Future<http.Response> Function(String? token) chamada,
    String mensagemErro,
  ) async {
    if (!await _salvarPendentesAntes()) return false;
    _isLoading = true;
    _ultimoErro = null;
    notifyListeners();
    try {
      final token = await AuthService.instance.token;
      final response = await chamada(token);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _ultimoErro = '$mensagemErro (status ${response.statusCode}).';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _ultimoErro = '$mensagemErro. Verifique a conexão.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
    if (_disposed) return true;
    await carregarDados(treinamentoId);
    return _error == null;
  }

  Map<String, String> _headersJson(String? token) {
    final headers = ApiConfig.getAuthHeaders(token);
    headers['Content-Type'] = 'application/json';
    return headers;
  }

  // Adicionar Dia
  Future<bool> adicionarDia(int treinamentoId, String dataFormatada) {
    return _alterarEstrutura(
      treinamentoId,
      (token) => http.post(
        Uri.parse('${ApiConfig.baseUrl}/treinamentos/dia'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({"sheetId": _sheetId, "data": dataFormatada}),
      ),
      'Não foi possível adicionar o dia',
    );
  }

  // Adicionar Aluno
  Future<bool> adicionarAluno(int treinamentoId, String nome, String email) {
    return _alterarEstrutura(
      treinamentoId,
      (token) => http.post(
        Uri.parse('${ApiConfig.baseUrl}/treinamentos/aluno'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({"sheetId": _sheetId, "nome": nome, "email": email}),
      ),
      'Não foi possível adicionar o aluno',
    );
  }

  // Remover Dia
  Future<bool> removerDia(int treinamentoId, int index) {
    return _alterarEstrutura(
      treinamentoId,
      (token) => http.delete(
        Uri.parse('${ApiConfig.baseUrl}/treinamentos/dia').replace(queryParameters: {
          'sheetId': _sheetId,
          'diaIndex': index.toString(),
        }),
        headers: _headersJson(token),
      ),
      'Não foi possível remover o dia',
    );
  }

  // Remover Aluno
  Future<bool> removerAluno(int treinamentoId, int rowIndex) {
    return _alterarEstrutura(
      treinamentoId,
      (token) => http.delete(
        Uri.parse('${ApiConfig.baseUrl}/treinamentos/aluno').replace(queryParameters: {
          'sheetId': _sheetId,
          'rowIndex': rowIndex.toString(),
        }),
        headers: _headersJson(token),
      ),
      'Não foi possível remover o aluno',
    );
  }
}
