import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Modal_step.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Steps/Configuracao_Inicial_Projeto_step/components.dart';
import 'package:fabrica_software_app/providers/modal_criacao_projeto_provider.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fabrica_software_app/config/projeto_dto.dart';
import 'package:fabrica_software_app/services/api_service.dart';

class AlocacaoRecursosStep extends ModalStep {
  @override
  String get title => 'Alocação de Recursos';
  @override
  String get tabName => 'Equipe & recursos';

  @override
  String get ajuda =>
      'Marque as pessoas que vão participar do projeto (ao menos uma) e os recursos que ele vai usar. Use a busca para encontrar mais rápido.';
  @override
  IconData get icon => FontAwesomeIcons.usersGear;
  @override
  List<Color> get cores => <Color>[Colors.teal, Colors.green];

  final GlobalKey<_AlocacaoContentState> _contentKey = GlobalKey();

  @override
  bool validar() => _contentKey.currentState?.validar() ?? true;

  @override
  Widget buildBody(BuildContext context) => _AlocacaoContent(key: _contentKey);

  @override
  Widget buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          Row(
            children: [
              OutlinedButton(
                onPressed: () =>
                    context.read<ModalCriacaoProjetoProvider>().previousIndex(),
                child: const Text('Voltar',
                    style: TextStyle(color: Colors.black87)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  // SÓ AVANÇA SE A VALIDAÇÃO PASSAR
                  if (_contentKey.currentState != null) {
                    if (_contentKey.currentState!.validar()) {
                      context.read<ModalCriacaoProjetoProvider>().nextIndex();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2962FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: Row(children: const [
                  Text('Próxima etapa'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios, size: 12)
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlocacaoContent extends StatefulWidget {
  const _AlocacaoContent({super.key});
  @override
  State<_AlocacaoContent> createState() => _AlocacaoContentState();
}

class _AlocacaoContentState extends State<_AlocacaoContent> {
  List<dynamic> _listaContribuidoresDB = [];
  List<dynamic> _listaRecursosDB = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait(
          [ApiService.getContribuidores(), ApiService.getRecursos()]);
      if (mounted) {
        setState(() {
          _listaContribuidoresDB = results[0];
          _listaRecursosDB = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- VALIDAÇÃO ---
  bool validar() {
    if (projetoDraft.equipe.isEmpty) {
      avisar(context, 'Adicione pelo menos uma pessoa à equipe do projeto.');
      return false;
    }
    return true;
  }

  void _alternarPessoa(dynamic pessoa) {
    setState(() {
      final indice =
          projetoDraft.equipe.indexWhere((e) => e['id'] == pessoa['id']);
      if (indice >= 0) {
        projetoDraft.equipe.removeAt(indice);
      } else {
        projetoDraft.equipe.add({
          'id': pessoa['id'],
          'nome': pessoa['nome'],
          'papel': pessoa['cargo'] ?? 'N/A'
        });
      }
    });
  }

  void _alternarRecurso(dynamic recurso) {
    setState(() {
      final indice =
          projetoDraft.recursos.indexWhere((r) => r['id'] == recurso['id']);
      if (indice >= 0) {
        projetoDraft.recursos.removeAt(indice);
      } else {
        projetoDraft.recursos.add({
          'id': recurso['id'],
          'nome': recurso['nome'],
          'tipo': recurso['tipo']
        });
      }
    });
  }

  Widget _cabecalho(String titulo, int marcados, {bool obrigatorio = false}) {
    return Row(
      children: [
        Expanded(
          child: ComponentsConfiguracaoInicalProjeto.buildLabel(titulo,
              isRequired: obrigatorio),
        ),
        if (marcados > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TagIdv(
                texto: '$marcados selecionado${marcados == 1 ? '' : 's'}',
                cor: CoresIdv.azul),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final equipe = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecalho('Equipe do projeto', projetoDraft.equipe.length,
            obrigatorio: true),
        BuscaSelecaoIdv(
          itens: _listaContribuidoresDB,
          rotulo: (c) => '${c['nome'] ?? ''}',
          detalhe: (c) => c['cargo'] as String?,
          comAvatar: true,
          hintBusca: 'Pesquisar pessoa ou cargo',
          textoVazio: 'Nenhum colaborador cadastrado.',
          textoNenhumSelecionado: 'Ninguém na equipe ainda.',
          marcado: (c) => projetoDraft.equipe.any((e) => e['id'] == c['id']),
          aoAlternar: _alternarPessoa,
        ),
      ],
    );

    final recursos = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecalho('Recursos', projetoDraft.recursos.length),
        BuscaSelecaoIdv(
          itens: _listaRecursosDB,
          rotulo: (r) => '${r['nome'] ?? ''}',
          detalhe: (r) => r['tipo'] as String?,
          grupo: (r) => r['tipo'] as String?,
          hintBusca: 'Pesquisar recurso ou tipo',
          textoVazio: 'Nenhum recurso cadastrado.',
          textoNenhumSelecionado: 'Nenhum recurso escolhido ainda.',
          marcado: (r) =>
              projetoDraft.recursos.any((item) => item['id'] == r['id']),
          aoAlternar: _alternarRecurso,
        ),
      ],
    );

    // Lado a lado quando cabe: não é preciso rolar a equipe para chegar
    // aos recursos.
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 720) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [equipe, const SizedBox(height: 28), recursos],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: equipe),
          const SizedBox(width: 24),
          Expanded(child: recursos),
        ],
      );
    });
  }
}
