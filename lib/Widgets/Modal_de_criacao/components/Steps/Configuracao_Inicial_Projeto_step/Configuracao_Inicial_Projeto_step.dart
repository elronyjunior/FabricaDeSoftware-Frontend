import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Modal_step.dart';
import 'package:fabrica_software_app/providers/modal_criacao_projeto_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'components.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/config/projeto_dto.dart';
import 'package:fabrica_software_app/services/api_service.dart';

class ConfiguracaoInicialProjetoStep extends ModalStep {
  @override
  String get title => 'Configuração inicial do projeto';

  @override
  String get tabName => 'Informações';

  @override
  String get ajuda =>
      'Dados gerais do projeto: nome, tipo, modelo, cliente e tecnologias. Os campos com * são obrigatórios.';

  @override
  IconData get icon => FontAwesomeIcons.gears;

  @override
  List<Color> get cores => <Color>[const Color.fromARGB(255, 4, 187, 233)];

  final GlobalKey<_ConfiguracaoContentState> _contentKey = GlobalKey();

  @override
  bool validar() => _contentKey.currentState?.validar() ?? true;

  @override
  Widget buildBody(BuildContext context) {
    return _ConfiguracaoContent(key: _contentKey);
  }

  @override
  Widget buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: () {
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
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Row(
              children: const [
                Text('Próxima etapa'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfiguracaoContent extends StatefulWidget {
  const _ConfiguracaoContent({super.key});

  @override
  State<_ConfiguracaoContent> createState() => _ConfiguracaoContentState();
}

class _ConfiguracaoContentState extends State<_ConfiguracaoContent> {
  final _formKey = GlobalKey<FormState>();

  // Inicializamos os controllers já com os dados do DTO para garantir que apareçam
  late TextEditingController _nomeCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _metodologiaCtrl;

  List<dynamic> _listaClientesDB = [];
  List<dynamic> _listaTecnologiasDB = [];

  Map<String, dynamic>? _clienteSelecionado;
  List<Map<String, dynamic>> _tecnologiasSelecionadas = [];

  String? _tipoSelecionado;
  final List<String> _opcoesTipo = [
    'Web',
    'Mobile',
    'Desktop',
    'API',
    'Híbrido',
    'Outro'
  ];

  String? _modeloSelecionado;
  final List<String> _opcoesModelo = [
    'SaaS',
    'Marketplace',
    'E-commerce',
    'Institucional',
    'Interno',
    'Outros'
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 1. Vínculo Imediato dos Dados Básicos (Evita delay visual)
    _nomeCtrl = TextEditingController(text: projetoDraft.nome ?? '');
    _descCtrl = TextEditingController(text: projetoDraft.descricao ?? '');
    _metodologiaCtrl = TextEditingController(
        text:
            projetoDraft.metodologia ?? ''); // <--- Aqui garante a Metodologia

    _carregarDadosAsync();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    _metodologiaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosAsync() async {
    try {
      // Busca listas gerais
      final results = await Future.wait(
          [ApiService.getClientes(), ApiService.getTecnologias()]);

      List<int> idsTecnologiasDoProjeto = [];

      // Se for EDIÇÃO (tem ID), busca as tecnologias específicas desse projeto no banco
      if (projetoDraft.id != null) {
        idsTecnologiasDoProjeto =
            await ApiService.getTecnologiasDoProjeto(projetoDraft.id!);
      }

      if (mounted) {
        setState(() {
          _listaClientesDB = results[0];
          _listaTecnologiasDB = results[1];

          // 2. Configura Dropdowns (Tipo e Modelo)
          if (projetoDraft.tipo != null) {
            _tipoSelecionado = _encontrarOpcao(projetoDraft.tipo!, _opcoesTipo);
          }
          if (projetoDraft.modelo != null) {
            _modeloSelecionado =
                _encontrarOpcao(projetoDraft.modelo!, _opcoesModelo);
          }

          // 3. Configura Cliente
          if (projetoDraft.cliente != null &&
              projetoDraft.cliente!['id'] != null) {
            try {
              final idDraft = projetoDraft.cliente!['id'].toString();
              _clienteSelecionado = _listaClientesDB.firstWhere(
                  (c) => c['id'].toString() == idDraft,
                  orElse: () => null);
              // Atualiza o DTO para garantir consistência
              if (_clienteSelecionado != null)
                projetoDraft.cliente = _clienteSelecionado;
            } catch (_) {}
          }

          // 4. Configura Tecnologias (A Mágica da Edição)
          if (projetoDraft.id != null && idsTecnologiasDoProjeto.isNotEmpty) {
            // Filtra da lista geral apenas as que o projeto tem
            // Compara como texto: os ids podem vir como número ou texto.
            final ids = idsTecnologiasDoProjeto.map((id) => '$id').toSet();
            _tecnologiasSelecionadas = _listaTecnologiasDB
                .where((tech) => ids.contains('${tech['id']}'))
                .map((e) => Map<String, dynamic>.from(e)) // Cria cópia segura
                .toList();

            // Salva no DTO para persistir
            projetoDraft.tecnologias = _tecnologiasSelecionadas;
          }
          // Se for CRIAÇÃO ou já tiver tecnologias no draft (navegação entre abas)
          else if (projetoDraft.tecnologias.isNotEmpty) {
            _tecnologiasSelecionadas = List.from(projetoDraft.tecnologias);
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erro no carregamento: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Opção da lista equivalente ao valor salvo. Valor fora da lista (ex.:
  /// tipo 'AI' dos projetos antigos) entra na lista, para não sumir da tela
  /// nem ser trocado por outro ao salvar.
  String? _encontrarOpcao(String valor, List<String> lista) {
    if (valor.trim().isEmpty) return null;
    for (final opcao in lista) {
      if (opcao.toUpperCase() == valor.toUpperCase()) return opcao;
    }
    lista.add(valor);
    return valor;
  }

  bool validar() {
    if (_nomeCtrl.text.trim().isEmpty) {
      _showError('O Nome do projeto é obrigatório.');
      return false;
    }
    if (_tipoSelecionado == null) {
      _showError('Selecione o Tipo do projeto.');
      return false;
    }
    if (_clienteSelecionado == null) {
      _showError('Selecione um Cliente.');
      return false;
    }
    // Salvamento final
    projetoDraft.nome = _nomeCtrl.text;
    projetoDraft.metodologia =
        _metodologiaCtrl.text; // Garante salvar metodologia
    return true;
  }

  void _showError(String msg) {
    avisar(context, msg);
  }

  void _alternarTecnologia(dynamic tech) {
    setState(() {
      if (_tecnologiasSelecionadas.any((t) => t['id'] == tech['id'])) {
        _tecnologiasSelecionadas.removeWhere((t) => t['id'] == tech['id']);
      } else {
        _tecnologiasSelecionadas.add(Map<String, dynamic>.from(tech));
      }
      projetoDraft.tecnologias = _tecnologiasSelecionadas;
    });
  }

  Widget _campoTexto(TextEditingController ctrl, String hint,
      {int maxLines = 1,
      required ValueChanged<String> aoMudar,
      required List<TextInputFormatter> formatos}) {
    return Container(
      decoration: ComponentsConfiguracaoInicalProjeto.inputBoxDecoration,
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: fonteIdv(),
        inputFormatters: formatos,
        decoration: ComponentsConfiguracaoInicalProjeto.inputDecoration(hint),
        onChanged: aoMudar,
      ),
    );
  }

  Widget _coluna(String label, Widget campo, {bool obrigatorio = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComponentsConfiguracaoInicalProjeto.buildLabel(label,
            isRequired: obrigatorio),
        campo,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    const espaco = SizedBox(height: 20);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _coluna(
            'Nome do projeto',
            _campoTexto(_nomeCtrl, 'Ex: Sistema de Gestão ERP',
                formatos: textoIdv(LimitesIdv.nome),
                aoMudar: (val) => projetoDraft.nome = val),
            obrigatorio: true,
          ),
          espaco,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _coluna(
                  'Tipo',
                  SelecaoIdv<String>(
                    hint: 'Selecione',
                    valor: _tipoSelecionado,
                    itens: _opcoesTipo,
                    rotulo: (t) => t,
                    aoMudar: (val) => setState(() {
                      _tipoSelecionado = val;
                      projetoDraft.tipo = val;
                    }),
                  ),
                  obrigatorio: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _coluna(
                  'Modelo',
                  SelecaoIdv<String>(
                    hint: 'Selecione',
                    valor: _modeloSelecionado,
                    itens: _opcoesModelo,
                    rotulo: (m) => m,
                    aoMudar: (val) => setState(() {
                      _modeloSelecionado = val;
                      projetoDraft.modelo = val;
                    }),
                  ),
                  obrigatorio: true,
                ),
              ),
            ],
          ),
          espaco,
          _coluna(
            'Descrição',
            _campoTexto(_descCtrl, 'Descreva o objetivo do projeto...',
                maxLines: 4,
                formatos: textoIdv(LimitesIdv.descricao),
                aoMudar: (val) => projetoDraft.descricao = val),
          ),
          espaco,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _coluna(
                  'Cliente',
                  BuscaSelecaoIdv(
                    unico: true,
                    itens: _listaClientesDB,
                    rotulo: (c) => '${c['razao_social'] ?? 'Sem nome'}',
                    detalhe: (c) => c['cnpj'] as String?,
                    hintBusca: 'Pesquisar cliente ou CNPJ',
                    textoVazio: 'Nenhum cliente cadastrado.',
                    textoNenhumSelecionado: 'Nenhum cliente escolhido.',
                    marcado: (c) =>
                        _clienteSelecionado != null &&
                        '${c['id']}' == '${_clienteSelecionado!['id']}',
                    aoAlternar: (c) => setState(() {
                      final mesmo = _clienteSelecionado != null &&
                          '${c['id']}' == '${_clienteSelecionado!['id']}';
                      _clienteSelecionado = mesmo ? null : c;
                      projetoDraft.cliente = _clienteSelecionado;
                    }),
                  ),
                  obrigatorio: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _coluna(
                  'Metodologia',
                  _campoTexto(_metodologiaCtrl, 'Ex: Scrum',
                      // Só letras, números e separadores simples (ex.: Scrum/Kanban).
                      formatos: [
                        ...textoIdv(LimitesIdv.metodologia),
                        FilteringTextInputFormatter.allow(
                            RegExp(r"[A-Za-zÀ-ÿ0-9 \-/&.+]")),
                      ],
                      aoMudar: (val) => projetoDraft.metodologia = val),
                ),
              ),
            ],
          ),
          espaco,
          Row(
            children: [
              Expanded(
                child: ComponentsConfiguracaoInicalProjeto.buildLabel(
                    'Tecnologias utilizadas',
                    isRequired: true),
              ),
              if (_tecnologiasSelecionadas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_tecnologiasSelecionadas.length} selecionada${_tecnologiasSelecionadas.length == 1 ? '' : 's'}',
                    style: fonteIdv(tamanho: 13, cor: CoresIdv.textoSecundario),
                  ),
                ),
            ],
          ),
          BuscaSelecaoIdv(
            itens: _listaTecnologiasDB,
            rotulo: (t) => '${t['nome'] ?? ''}',
            grupo: (t) => t['categoria'] as String?,
            listarSemBusca: true,
            hintBusca: 'Pesquisar tecnologia ou categoria',
            textoVazio: 'Nenhuma tecnologia cadastrada.',
            textoNenhumSelecionado: 'Nenhuma tecnologia escolhida ainda.',
            marcado: (tech) =>
                _tecnologiasSelecionadas.any((t) => t['id'] == tech['id']),
            aoAlternar: _alternarTecnologia,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
