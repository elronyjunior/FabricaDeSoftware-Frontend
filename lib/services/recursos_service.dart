import '../models/recurso.dart';
import 'base_api_service.dart';

class RecursosService extends BaseApiService {
  // Singleton
  static final RecursosService instance = RecursosService._();

  // Define '/recursos' como endpoint base deste serviço
  RecursosService._() : super('/recursos');

  // Listar todos os recursos (Rota: /api/recursos)
  Future<List<Recurso>> listarRecursos() async {
    return getAll<Recurso>(Recurso.fromJson);
  }

  /// Projetos em que o recurso está vinculado (nome do projeto + custo/hora
  /// e data de alocação do vínculo). Rota: /api/recursos/:id/projetos
  Future<List<Map<String, dynamic>>> projetosDoRecurso(int id) async {
    final resposta = await get('/$id/projetos');
    return handleResponse(resposta, (json) {
      if (json is! List) throw ApiException('Resposta inválida do servidor');
      return json.cast<Map<String, dynamic>>();
    });
  }

  // Listar recursos de um projeto específico
  // Rota Backend: /api/recursos-projeto/projeto/:id
  // Como o endpoint base é '/recursos', usamos '/..' para voltar um nível e acessar a outra rota
  Future<List<Recurso>> listarRecursosPorProjeto(int projetoId) async {
    return getAll<Recurso>(
      Recurso.fromJson,
      path: '/../recursos-projeto/projeto/$projetoId',
    );
  }

  // Buscar um recurso por ID
  Future<Recurso> buscarRecurso(int id) async {
    return getById<Recurso>(id, Recurso.fromJson);
  }

  // Criar novo recurso
  Future<Recurso> criarRecurso(Map<String, dynamic> data) async {
    return create<Recurso>(data, Recurso.fromJson);
  }

  // Atualizar recurso existente
  Future<Recurso> atualizarRecurso(int id, Map<String, dynamic> data) async {
    return update<Recurso>(id, data, Recurso.fromJson);
  }

  // Excluir recurso
  Future<void> excluirRecurso(int id) async {
    return delete(id);
  }
}