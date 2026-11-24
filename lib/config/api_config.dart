/// Configuração única da API (antes havia uma cópia em services/).
class ApiConfig {
  static const String baseUrl = 'http://localhost:3000/api';

  static Map<String, String> getAuthHeaders(String? token) {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Endpoints
  static const String usuarios = '/usuarios';
  static const String clientes = '/clientes';
  static const String enderecos = '/enderecos';
  static const String projetos = '/projetos';
  static const String recursos = '/recursos';
  static const String tecnologias = '/tecnologias';
  static const String contribuidores = '/contribuidores';
  static const String requisitos = '/requisitos';
  static const String documentos = '/documentos';
  static const String treinamentos = '/treinamentos';
  static const String testes = '/testes';
  static const String logs = '/logs';

  // Endpoints de relacionamentos
  static const String recursosProjeto = '/recursos-projeto';
  static const String tecnologiasProjeto = '/tecnologias-projeto';
  static const String contribuidoresProjeto = '/contribuidores-projeto';
  static const String requisitosProjeto = '/requisitos-projeto';
}
