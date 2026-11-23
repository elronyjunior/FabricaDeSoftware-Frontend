import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Modal_step.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Steps/Configuracao_Inicial_Projeto_step/components.dart';
import 'package:fabrica_software_app/providers/modal_criacao_projeto_provider.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fabrica_software_app/config/projeto_dto.dart';
import 'package:fabrica_software_app/services/api_service.dart';
import 'package:fabrica_software_app/providers/auth_provider.dart'; // Import necessário

class PlanejamentoOrcamentoStep extends ModalStep {
  @override
  String get title => 'Planejamento & Orçamento';

  @override
  String get tabName => 'Planejamento';

  @override
  String get ajuda =>
      'Escolha o período do projeto no calendário (início e fim) e informe o orçamento, ou peça uma estimativa à IA.';

  @override
  IconData get icon => FontAwesomeIcons.calendarCheck.data;

  @override
  List<Color> get cores => <Color>[Colors.orangeAccent, Colors.deepOrange];

  final GlobalKey<_PlanejamentoContentState> _contentKey = GlobalKey();

  /// Envia o projeto. `true` quando foi criado (quem chamou fecha o modal).
  Future<bool> concluir() async =>
      await _contentKey.currentState?.finalizarProjeto() ?? false;

  @override
  Widget buildBody(BuildContext context) {
    return _PlanejamentoContent(key: _contentKey);
  }

  @override
  Widget buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () {
              projetoDraft.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  if (_contentKey.currentState != null) {
                    _contentKey.currentState!.limparEtapa();
                  }
                  context.read<ModalCriacaoProjetoProvider>().previousIndex();
                },
                child: const Text('Voltar',
                    style: TextStyle(color: Colors.black87)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  if (await concluir() && context.mounted) {
                    Navigator.pop(context);
                    avisar(context, "Projeto criado!", tipo: TipoAviso.sucesso);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Row(
                  children: const [
                    Text('CRIAR PROJETO',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.check, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanejamentoContent extends StatefulWidget {
  const _PlanejamentoContent({super.key});

  @override
  State<_PlanejamentoContent> createState() => _PlanejamentoContentState();
}

class _PlanejamentoContentState extends State<_PlanejamentoContent> {
  final _dataInicioCtrl = TextEditingController();
  final _dataFimCtrl = TextEditingController();
  final _orcamentoCtrl = TextEditingController();

  DateTime? _dataInicio;
  DateTime? _dataFim;

  bool _isCalculatingIA = false;
  bool _isSending = false;

  void limparEtapa() {
    _dataInicioCtrl.clear();
    _dataFimCtrl.clear();
    _orcamentoCtrl.clear();
    projetoDraft.dataInicio = null;
    projetoDraft.dataFinalPrevista = null;
    projetoDraft.orcamentoEstimado = null;
    projetoDraft.complexidade = null;
  }

  // O campo de período devolve início e fim juntos; os controllers seguem
  // preenchidos porque a validação de finalizarProjeto confere o texto deles.
  void _mudarPeriodo(DateTime? inicio, DateTime? fim) {
    setState(() {
      _dataInicio = inicio;
      _dataFim = fim;
      _dataInicioCtrl.text = inicio == null ? '' : formatarDataIdv(inicio);
      _dataFimCtrl.text = fim == null ? '' : formatarDataIdv(fim);
    });
  }

  Future<void> _estimarOrcamentoIA() async {
    if (_dataInicio == null || _dataFim == null) {
      avisar(context, 'Escolha o período do projeto antes de estimar.',
          tipo: TipoAviso.info);
      return;
    }

    setState(() => _isCalculatingIA = true);

    try {
      final dias = _dataFim!.difference(_dataInicio!).inDays;
      final dadosParaIA = {
        "nome": projetoDraft.nome,
        "descricao": projetoDraft.descricao,
        "escopo": projetoDraft.escopo ?? "",
        "duracao_dias": dias,
        "equipe": projetoDraft.equipe,
        "recursos": projetoDraft.recursos
      };

      final resultado = await ApiService.estimarOrcamentoBackend(dadosParaIA);

      setState(() {
        final bruto = resultado['orcamento_estimado'];
        double valor = bruto is num
            ? bruto.toDouble()
            : double.tryParse(bruto.toString()) ?? 0.0;
        String complexidade = resultado['complexidade'] ?? 'media';
        _orcamentoCtrl.text = formatarMoedaBr(valor);
        projetoDraft.orcamentoEstimado = valor;
        projetoDraft.complexidade = complexidade;
      });
    } catch (e) {
      if (mounted) avisar(context, mensagemErroIa(e));
    } finally {
      setState(() => _isCalculatingIA = false);
    }
  }

  /// Envia o projeto e devolve `true` quando ele foi criado. Fechar o modal
  /// e avisar o sucesso fica com quem chamou.
  Future<bool> finalizarProjeto() async {
    if (_dataInicioCtrl.text.isEmpty || _dataFimCtrl.text.isEmpty) {
      avisar(context, 'Escolha o período do projeto no calendário.');
      return false;
    }
    final orcamento = lerMoedaBr(_orcamentoCtrl.text);
    if (orcamento == null || orcamento <= 0) {
      avisar(context, 'Informe um orçamento maior que zero.');
      return false;
    }

    setState(() => _isSending = true);

    try {
      // 1. PEGA O ID DO USUÁRIO LOGADO (Correção Principal)
      final usuarioLogadoId = context.read<AuthProvider>().userId;

      if (usuarioLogadoId == null) {
        throw Exception("Sessão inválida. Faça login novamente.");
      }

      projetoDraft.dataInicio = _dataInicio;
      projetoDraft.dataFinalPrevista = _dataFim;
      projetoDraft.orcamentoEstimado = orcamento;
      if (projetoDraft.complexidade == null)
        projetoDraft.complexidade = 'media';

      final payload = projetoDraft.montarPayloadCriacao(usuarioLogadoId);

      await ApiService.criarProjetoCompleto(payload);

      projetoDraft.clear();
      return true;
    } catch (e) {
      if (mounted) {
        avisar(context, 'Não foi possível criar o projeto: $e');
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSending) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComponentsConfiguracaoInicalProjeto.buildLabel('Período do projeto',
            isRequired: true),
        PeriodoIdv(
          inicio: _dataInicio,
          fim: _dataFim,
          aoMudar: _mudarPeriodo,
        ),
        const SizedBox(height: 24),
        ComponentsConfiguracaoInicalProjeto.buildLabel('Orçamento estimado',
            isRequired: true),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                decoration:
                    ComponentsConfiguracaoInicalProjeto.inputBoxDecoration,
                child: TextField(
                  controller: _orcamentoCtrl,
                  keyboardType: TextInputType.number,
                  // Só números; a vírgula e os pontos entram sozinhos.
                  inputFormatters: [FormatoMoedaBr()],
                  style: fonteIdv(),
                  textAlignVertical: TextAlignVertical.center,
                  decoration:
                      ComponentsConfiguracaoInicalProjeto.inputDecoration(
                              '0,00')
                          .copyWith(
                    prefixText: 'R\$  ',
                    prefixStyle: fonteIdv(cor: CoresIdv.textoSecundario),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            BotaoIa(
              rotulo: 'Estimar com IA',
              rotuloCarregando: 'Estimando...',
              carregando: _isCalculatingIA,
              aoTocar: _estimarOrcamentoIA,
              larguraTotal: false,
            ),
          ],
        ),
      ],
    );
  }
}
