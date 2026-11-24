import 'package:fabrica_software_app/providers/auth_provider.dart';
import 'package:fabrica_software_app/services/api_service.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

// Imports
import 'package:fabrica_software_app/config/projeto_dto.dart';
import 'package:fabrica_software_app/services/projetos_service.dart';
import 'package:fabrica_software_app/providers/projetos_provider.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Modal_step.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Steps/Configuracao_Inicial_Projeto_step/Configuracao_Inicial_Projeto_step.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Steps/Configuracao_Inicial_Projeto_step/components.dart';

class EdicaoProjetoStep extends ModalStep {
  final _basicInfoStep = ConfiguracaoInicialProjetoStep();

  @override
  String get title => 'Editar Informações Básicas';
  @override
  String get tabName => 'Informações';
  @override
  String get ajuda =>
      'Altere as informações gerais do projeto. Os campos com * são obrigatórios.';
  @override
  IconData get icon => FontAwesomeIcons.penToSquare;
  @override
  List<Color> get cores => [Colors.blue.shade700, Colors.blue.shade500];

  final GlobalKey<_PlanejamentoEdicaoState> _planejamentoKey = GlobalKey();

  @override
  bool validar() =>
      _basicInfoStep.validar() &&
      (_planejamentoKey.currentState?.validar() ?? true);

  // Além das informações gerais, a edição permite mudar o período, o
  // orçamento e marcar o término real (data_final): sem ele nenhum projeto
  // chegava a "Concluído".
  @override
  Widget buildBody(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _basicInfoStep.buildBody(context),
          const SizedBox(height: 20),
          _PlanejamentoEdicao(key: _planejamentoKey),
        ],
      );

  @override
  Widget buildFooter(BuildContext context) => _EdicaoFooter(etapa: this);

  /// Envia as alterações. `true` quando salvou (quem chamou fecha o modal).
  Future<bool> concluirEdicao(BuildContext context) async {
    try {
      // DTO já está atualizado pelo formulário.
      // Montamos o pacote completo para não apagar dados no banco.
      final dados = {
        'nome_projeto': projetoDraft.nome,
        'descricao': projetoDraft.descricao,
        'tipo': projetoDraft.tipo,
        'modelo_projeto': projetoDraft.modelo,
        'metodologia': projetoDraft.metodologia,
        'escopo': projetoDraft.escopo, // Mantém o que veio do loadFromModel
        'complexidade': projetoDraft.complexidade, // Mantém
        'orcamento_estimado': projetoDraft.orcamentoEstimado, // Editável
        'data_inicio': projetoDraft.dataInicio?.toIso8601String(),
        'data_final_previsto':
            projetoDraft.dataFinalPrevista?.toIso8601String(),
        // Término real: preenchido marca o projeto como concluído.
        'data_final': projetoDraft.dataFinal?.toIso8601String(),
        'cliente_id':
            projetoDraft.cliente != null ? projetoDraft.cliente!['id'] : null,
        // O back grava todos os campos: sem isso o responsável era apagado.
        'responsavel_id': projetoDraft.responsavel?['id'],
      };

      if (projetoDraft.id != null) {
        await ProjetosService.instance
            .atualizarProjeto(projetoDraft.id!, dados);

        // O PUT de projetos não mexe nas tecnologias: elas são salvas à
        // parte (adiciona as novas e remove as que foram desmarcadas).
        if (!context.mounted) return false;
        final usuarioId = context.read<AuthProvider>().userId ?? 0;
        await ApiService.sincronizarTecnologiasDoProjeto(
          projetoDraft.id!,
          {
            for (final t in projetoDraft.tecnologias)
              if (int.tryParse('${t['id']}') != null) int.parse('${t['id']}'),
          },
          aprovadoPorId: usuarioId,
        );
      }
      if (context.mounted) {
        context.read<ProjetosProvider>().carregarProjetos();
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        avisar(context, 'Não foi possível salvar as alterações: $e');
      }
      return false;
    }
  }
}

// Rodapé usado pelo modal antigo (ModalDeCriacao).
class _EdicaoFooter extends StatefulWidget {
  const _EdicaoFooter({required this.etapa});
  final EdicaoProjetoStep etapa;

  @override
  State<_EdicaoFooter> createState() => _EdicaoFooterState();
}

class _EdicaoFooterState extends State<_EdicaoFooter> {
  bool _isSaving = false;

  Future<void> _salvarAlteracoes() async {
    if (!widget.etapa.validar()) return;
    setState(() => _isSaving = true);
    final salvo = await widget.etapa.concluirEdicao(context);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (salvo) {
      Navigator.pop(context);
      avisar(context, 'Projeto atualizado!', tipo: TipoAviso.sucesso);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _salvarAlteracoes,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check, size: 18),
            label: Text(_isSaving ? 'Salvando...' : 'Salvar Alterações'),
          ),
        ],
      ),
    );
  }
}


/// Período, orçamento e término real na edição. Usa os mesmos campos do
/// passo de Planejamento (PeriodoIdv e o campo de moeda) e grava direto no
/// [projetoDraft], que é o que [EdicaoProjetoStep.concluirEdicao] envia.
class _PlanejamentoEdicao extends StatefulWidget {
  const _PlanejamentoEdicao({super.key});

  @override
  State<_PlanejamentoEdicao> createState() => _PlanejamentoEdicaoState();
}

class _PlanejamentoEdicaoState extends State<_PlanejamentoEdicao> {
  final _orcamentoCtrl = TextEditingController();
  final _terminoCtrl = TextEditingController();
  bool _calendarioAberto = false;

  @override
  void initState() {
    super.initState();
    final orcamento = projetoDraft.orcamentoEstimado;
    if (orcamento != null && orcamento > 0) {
      _orcamentoCtrl.text = formatarMoedaBr(orcamento);
    }
    final termino = projetoDraft.dataFinal;
    if (termino != null) _terminoCtrl.text = formatarDataIdv(termino);
  }

  @override
  void dispose() {
    _orcamentoCtrl.dispose();
    _terminoCtrl.dispose();
    super.dispose();
  }

  bool validar() {
    final inicio = projetoDraft.dataInicio;
    final previsto = projetoDraft.dataFinalPrevista;
    if (inicio == null || previsto == null) {
      avisar(context, 'Escolha o período do projeto no calendário.');
      return false;
    }
    final termino = projetoDraft.dataFinal;
    if (termino != null &&
        DateTime(termino.year, termino.month, termino.day)
            .isBefore(DateTime(inicio.year, inicio.month, inicio.day))) {
      avisar(context, 'O término real não pode ser antes do início.');
      return false;
    }
    final orcamento = projetoDraft.orcamentoEstimado;
    if (orcamento == null || orcamento <= 0) {
      avisar(context, 'Informe um orçamento maior que zero.');
      return false;
    }
    return true;
  }

  void _escolherTermino(DateTime? dia) {
    setState(() {
      projetoDraft.dataFinal = dia;
      _terminoCtrl.text = dia == null ? '' : formatarDataIdv(dia);
      if (dia != null) _calendarioAberto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComponentsConfiguracaoInicalProjeto.buildLabel('Período do projeto',
            isRequired: true),
        PeriodoIdv(
          inicio: projetoDraft.dataInicio,
          fim: projetoDraft.dataFinalPrevista,
          aoMudar: (inicio, fim) => setState(() {
            projetoDraft.dataInicio = inicio;
            projetoDraft.dataFinalPrevista = fim;
          }),
        ),
        const SizedBox(height: 20),
        ComponentsConfiguracaoInicalProjeto.buildLabel('Orçamento estimado',
            isRequired: true),
        Container(
          height: 50,
          decoration: ComponentsConfiguracaoInicalProjeto.inputBoxDecoration,
          child: TextField(
            controller: _orcamentoCtrl,
            keyboardType: TextInputType.number,
            // Mesma máscara do passo de Planejamento.
            inputFormatters: [FormatoMoedaBr()],
            style: fonteIdv(),
            textAlignVertical: TextAlignVertical.center,
            onChanged: (v) => projetoDraft.orcamentoEstimado = lerMoedaBr(v),
            decoration:
                ComponentsConfiguracaoInicalProjeto.inputDecoration('0,00')
                    .copyWith(
              prefixText: 'R\$  ',
              prefixStyle: fonteIdv(cor: CoresIdv.textoSecundario),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ComponentsConfiguracaoInicalProjeto.buildLabel('Término real'),
        Container(
          height: 50,
          decoration: ComponentsConfiguracaoInicalProjeto.inputBoxDecoration,
          child: TextField(
            controller: _terminoCtrl,
            readOnly: true,
            onTap: () => setState(() => _calendarioAberto = !_calendarioAberto),
            style: fonteIdv(),
            textAlignVertical: TextAlignVertical.center,
            decoration: ComponentsConfiguracaoInicalProjeto.inputDecoration(
                    'Preencha quando o projeto for concluído')
                .copyWith(
              suffixIcon: _terminoCtrl.text.isEmpty
                  ? const Icon(Icons.calendar_today_outlined,
                      color: CoresIdv.textoSecundario, size: 20)
                  : IconButton(
                      tooltip: 'Limpar término real',
                      icon: const Icon(Icons.close,
                          color: CoresIdv.textoSecundario, size: 20),
                      onPressed: () => _escolherTermino(null),
                    ),
            ),
          ),
        ),
        if (_calendarioAberto)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CalendarioDiaIdv(
              selecionado: projetoDraft.dataFinal,
              aoEscolher: _escolherTermino,
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
