import 'package:fabrica_software_app/Widgets/Barra_lateral/Barra_Lateral.dart';
import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/models/documento.dart';
import 'package:fabrica_software_app/models/enums.dart';
import 'package:fabrica_software_app/models/projeto.dart';
import 'package:fabrica_software_app/models/recurso.dart';
import 'package:fabrica_software_app/models/recurso_projeto.dart';
import 'package:fabrica_software_app/models/teste.dart';
import 'package:fabrica_software_app/models/treinamento.dart';
import 'package:fabrica_software_app/providers/projetos_provider.dart';
import 'package:fabrica_software_app/screens/Documento/Criar_Doc_Modal.dart';
import 'package:fabrica_software_app/screens/Documento/Documentos_Projeto_Screen.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/components/escala_design.dart';
import 'package:fabrica_software_app/screens/Recursos/recursos_do_projeto.dart';
import 'package:fabrica_software_app/screens/Relatorio/components/pecas_relatorio.dart';
import 'package:fabrica_software_app/screens/Tests/Teste_modal.dart';
import 'package:fabrica_software_app/screens/Treinamentos/ControlePresencaScreen.dart';
import 'package:fabrica_software_app/screens/Treinamentos/ModalCriarTreinamento.dart';
import 'package:fabrica_software_app/services/documentos_service.dart';
import 'package:fabrica_software_app/services/recurso_projeto_service.dart';
import 'package:fabrica_software_app/services/recursos_service.dart';
import 'package:fabrica_software_app/services/teste_service.dart';
import 'package:fabrica_software_app/services/treinamento_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// =====================================================================
// Visualizar projeto: o mesmo modelo de Relatórios (abas sublinhadas,
// indicadores e painéis), só com dados reais do projeto.
// =====================================================================

enum _Aba {
  resumo('Resumo'),
  recursos('Recursos'),
  testes('Testes'),
  artefatos('Artefatos'),
  treinamentos('Treinamentos');

  const _Aba(this.rotulo);
  final String rotulo;
}

class VisualizarProjetoScreen extends StatefulWidget {
  final Projeto projeto;

  const VisualizarProjetoScreen({super.key, required this.projeto});

  @override
  State<VisualizarProjetoScreen> createState() =>
      _VisualizarProjetoScreenState();
}

class _VisualizarProjetoScreenState extends State<VisualizarProjetoScreen> {
  _Aba _aba = _Aba.resumo;
  bool _carregando = true;

  List<RecursoProjeto> _vinculos = [];
  Map<int, Recurso> _recursos = {};
  List<Teste> _testes = [];
  List<Documento> _documentos = [];
  List<Treinamento> _treinamentos = [];

  /// Listas que não carregaram (mostra o aviso na aba delas).
  final Set<_Aba> _falhas = {};

  Projeto get p => widget.projeto;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final id = p.id;
    if (id == null) {
      setState(() => _carregando = false);
      return;
    }
    setState(() {
      _carregando = true;
      _falhas.clear();
    });

    Future<T?> pegar<T>(_Aba aba, Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        _falhas.add(aba);
        return null;
      }
    }

    final r = await Future.wait([
      // A rota /recursos-projeto/projeto/:id devolve só os dados do recurso
      // (sem os do vínculo); a lista geral traz tudo e é filtrada aqui, como
      // no painel "Recursos do projeto".
      pegar(_Aba.recursos, () => RecursoProjetoService().getRecursosProjeto()),
      pegar(_Aba.recursos, () => RecursosService.instance.listarRecursos()),
      pegar(_Aba.testes, () => TesteService().getTestesByProjeto(id)),
      pegar(_Aba.artefatos, () => DocumentosService.instance.listarPorProjeto(id)),
      pegar(_Aba.treinamentos, () => TreinamentoService().getTreinamentos()),
    ]);
    if (!mounted) return;
    setState(() {
      _vinculos = [
        for (final v in (r[0] as List<RecursoProjeto>?) ?? <RecursoProjeto>[])
          if (v.projetoId == id) v
      ];
      _recursos = {
        for (final x in (r[1] as List<Recurso>?) ?? <Recurso>[])
          if (x.id != null) x.id!: x
      };
      _testes = (r[2] as List<Teste>?) ?? [];
      _documentos = (r[3] as List<Documento>?) ?? [];
      _treinamentos = [
        for (final t in (r[4] as List<Treinamento>?) ?? <Treinamento>[])
          if (t.projetoId == id) t
      ];
      _carregando = false;
    });
  }

  Future<void> _abrirPagina(Widget pagina) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pagina));
    if (mounted) _carregar();
  }

  Future<void> _gerenciarRecursos() async {
    await abrirRecursosDoProjeto(context, p);
    if (mounted) _carregar();
  }

  Future<void> _novoTeste() async {
    await mostrarDialogo(
      context: context,
      barrierDismissible: false,
      builder: (_) => TesteModal(
        projetoId: p.id ?? 0,
        onSave: (t) async {
          await TesteService().createTeste(t);
          avisarApp('Teste criado.', tipo: TipoAviso.sucesso);
        },
      ),
    );
    if (mounted) _carregar();
  }

  Future<void> _editarTeste(Teste teste) async {
    await mostrarDialogo(
      context: context,
      barrierDismissible: false,
      builder: (_) => TesteModal(
        projetoId: p.id ?? 0,
        testeExistente: teste,
        onSave: (t) async {
          await TesteService().updateTeste(t);
          avisarApp('Teste atualizado.', tipo: TipoAviso.sucesso);
        },
      ),
    );
    if (mounted) _carregar();
  }

  Future<void> _excluirTeste(Teste teste) => _confirmarExclusao(
        titulo: 'Excluir teste',
        nome: teste.nome,
        acao: () => TesteService().deleteTeste(teste.id!),
        sucesso: 'Teste excluído.',
      );

  Future<void> _editarTreinamento(Treinamento treinamento) async {
    await mostrarDialogo(
      context: context,
      builder: (_) => ModalCriarTreinamento(
        projetoId: p.id ?? 0,
        treinamentoEdicao: treinamento.toJson(),
        onSuccess: () {},
      ),
    );
    if (mounted) _carregar();
  }

  Future<void> _excluirTreinamento(Treinamento treinamento) =>
      _confirmarExclusao(
        titulo: 'Excluir treinamento',
        nome: treinamento.nome,
        acao: () => TreinamentoService().deleteTreinamento(treinamento.id!),
        sucesso: 'Treinamento excluído.',
      );

  /// Controle de presença (planilha do treinamento).
  void _presenca(Treinamento treinamento) => _abrirPagina(ControlePresencaScreen(
        treinamentoId: treinamento.id ?? 0,
        tituloTreinamento: treinamento.nome,
      ));

  Future<void> _confirmarExclusao({
    required String titulo,
    required String nome,
    required Future<void> Function() acao,
    required String sucesso,
  }) async {
    final confirmou = await mostrarDialogo<bool>(
      context: context,
      builder: (ctx) => ConfirmacaoIdv(
        titulo: titulo,
        mensagem: '$nome será excluído. Essa ação não pode ser desfeita.',
        rotuloAcao: titulo,
        aoConfirmar: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirmou != true) return;
    try {
      await acao();
      avisarApp(sucesso, tipo: TipoAviso.sucesso);
    } catch (_) {
      avisarApp('Não foi possível excluir. Tente novamente.');
    }
    if (mounted) _carregar();
  }

  Future<void> _novoDocumento() async {
    await mostrarDialogo(
      context: context,
      builder: (_) =>
          ModalCriarDocIA(projetoId: p.id ?? 0, onSuccess: () {}),
    );
    if (mounted) _carregar();
  }

  Future<void> _novoTreinamento() async {
    await mostrarDialogo(
      context: context,
      builder: (_) =>
          ModalCriarTreinamento(projetoId: p.id ?? 0, onSuccess: () {}),
    );
    if (mounted) _carregar();
  }

  /// Botão de criar + ícone para a página completa (editar, excluir,
  /// presença, abrir o documento).
  Widget _acoes({
    required String rotulo,
    required VoidCallback aoCriar,
    required String dicaPagina,
    required Widget pagina,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: dicaPagina,
          onPressed: () => _abrirPagina(pagina),
          icon: const Icon(Icons.open_in_new_rounded,
              size: 20, color: StyleProjetos.textoSecundario),
        ),
        const SizedBox(width: 6),
        BotaoSecundarioIdv(
            rotulo: rotulo, icone: Icons.add_rounded, aoTocar: aoCriar),
      ],
    );
  }

  double get _custoRecursos =>
      _vinculos.fold(0.0, (soma, v) => soma + v.custoEstimado());

  @override
  Widget build(BuildContext context) {
    final desktop = LayoutPrincipal.menuFixo(context);
    return Scaffold(
      drawer: BarraLateral.drawer(context),
      backgroundColor: desktop ? Colors.transparent : null,
      body: DecoratedBox(
        decoration: desktop
            ? const BoxDecoration()
            : const BoxDecoration(gradient: StyleProjetos.gradienteFundo),
        child: SafeArea(
          child: desktop
              ? EscalaDesign(
                  larguraBase: LayoutPrincipal.larguraBase -
                      LayoutPrincipal.recuoConteudo,
                  child: _conteudo(true),
                )
              : _conteudo(false),
        ),
      ),
    );
  }

  Widget _conteudo(bool desktop) {
    return SingleChildScrollView(
      padding: desktop
          ? const EdgeInsets.fromLTRB(25, 48, 36, 32)
          : const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cabecalho(projeto: p, desktop: desktop),
          SizedBox(height: desktop ? 36 : 20),
          AbasSublinhadas(
            rotulos: [for (final a in _Aba.values) a.rotulo],
            atual: _aba.index,
            aoMudar: (i) => setState(() => _aba = _Aba.values[i]),
          ),
          const SizedBox(height: 22),
          if (_carregando)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                  child: CircularProgressIndicator(color: CoresIdv.laranja)),
            )
          else ...[
            if (_falhas.contains(_aba))
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: _AvisoFalha(),
              ),
            switch (_aba) {
              _Aba.resumo => _resumo(desktop),
              _Aba.recursos => _abaRecursos(),
              _Aba.testes => _abaTestes(desktop),
              _Aba.artefatos => _abaArtefatos(),
              _Aba.treinamentos => _abaTreinamentos(),
            },
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Resumo

  Widget _resumo(bool desktop) {
    final membros = context.watch<ProjetosProvider>().membrosDoProjeto(p.id);
    final prazo = _prazo();

    final indicadores = [
      IndicadorRelatorio(
        icone: Icons.payments_outlined,
        titulo: 'Orçamento estimado',
        valor: p.orcamentoEstimado == null
            ? 'Não estimado'
            : moeda.format(p.orcamentoEstimado),
        detalhe: 'Definido na criação do projeto',
        destaque: true,
      ),
      IndicadorRelatorio(
        icone: Icons.inventory_2_outlined,
        titulo: 'Custo dos recursos',
        valor: dinheiroCurto(_custoRecursos),
        detalhe: _vinculos.length == 1
            ? '1 recurso vinculado'
            : '${_vinculos.length} recursos vinculados',
      ),
      IndicadorRelatorio(
        icone: Icons.event_outlined,
        titulo: 'Prazo',
        valor: prazo.valor,
        complemento: prazo.complemento,
        detalhe: prazo.detalhe,
      ),
      IndicadorRelatorio(
        icone: Icons.groups_outlined,
        titulo: 'Equipe',
        valor: '${membros.length}',
        complemento: membros.length == 1 ? ' pessoa' : ' pessoas',
        detalhe: membros.isEmpty
            ? 'Ninguém vinculado ainda'
            : membros.take(2).map((m) => m.nome.split(' ').first).join(', ') +
                (membros.length > 2 ? ' e mais ${membros.length - 2}' : ''),
      ),
    ];

    final sobre = CartaoRelatorio(
      titulo: 'Sobre o projeto',
      subtitulo: p.clienteNome == null ? null : 'Cliente: ${p.clienteNome}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _ou(p.descricao, 'Sem descrição.'),
            style: fonteIdv(tamanho: 14, altura: 1.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 28,
            runSpacing: 16,
            children: [
              _Info('Tipo', _ou(p.tipo, 'Não informado')),
              _Info('Modelo', _ou(p.modeloProjeto, 'Não informado')),
              _Info('Metodologia', _ou(p.metodologia, 'Não informada')),
              _InfoWidget('Complexidade', _Complexidade(p.complexidade)),
            ],
          ),
          if ((p.escopo ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            _Info('Escopo', p.escopo!.trim(), largo: true),
          ],
        ],
      ),
    );

    final planejamento = CartaoRelatorio(
      titulo: 'Planejamento',
      child: Column(
        children: [
          _LinhaData('Início', p.dataInicio),
          _LinhaData('Previsão de término', p.dataFinalPrevisto),
          _LinhaData('Término real', p.dataFinal, vazio: 'Em andamento'),
          _LinhaTexto('Duração prevista', _duracao(), ultima: true),
        ],
      ),
    );

    final equipe = CartaoRelatorio(
      titulo: 'Equipe',
      subtitulo: 'Pessoas vinculadas em Gestão de Equipes',
      child: membros.isEmpty
          ? const SemDados(texto: 'Ninguém vinculado ao projeto.')
          : Column(
              children: [
                for (var i = 0; i < membros.length; i++)
                  _Pessoa(nome: membros[i].nome, ultima: i == membros.length - 1),
              ],
            ),
    );

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final k in indicadores) ...[k, const SizedBox(height: 12)],
          const SizedBox(height: 8),
          sobre,
          const SizedBox(height: 16),
          planejamento,
          const SizedBox(height: 16),
          equipe,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < indicadores.length; i++) ...[
              if (i > 0) const SizedBox(width: 18),
              Expanded(child: indicadores[i]),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: sobre),
            const SizedBox(width: 18),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [planejamento, const SizedBox(height: 18), equipe],
              ),
            ),
          ],
        ),
      ],
    );
  }

  ({String valor, String? complemento, String detalhe}) _prazo() {
    String data(DateTime d) => dataCurta.format(d);
    if (p.dataFinal != null) {
      return (
        valor: 'Concluído',
        complemento: null,
        detalhe: 'em ${data(p.dataFinal!)}'
      );
    }
    final previsto = p.dataFinalPrevisto;
    if (previsto == null) {
      return (valor: 'Sem prazo', complemento: null, detalhe: 'Previsão não definida');
    }
    final hoje = DateUtils.dateOnly(DateTime.now());
    final dias = DateUtils.dateOnly(previsto).difference(hoje).inDays;
    if (dias >= 0) {
      return (
        valor: '$dias',
        complemento: dias == 1 ? ' dia' : ' dias',
        detalhe: 'restantes · até ${data(previsto)}'
      );
    }
    return (
      valor: '${-dias}',
      complemento: -dias == 1 ? ' dia' : ' dias',
      detalhe: 'de atraso · previsto ${data(previsto)}'
    );
  }

  String _duracao() {
    final ini = p.dataInicio;
    final fim = p.dataFinal ?? p.dataFinalPrevisto;
    if (ini == null || fim == null) return 'Não definida';
    final dias = fim.difference(ini).inDays;
    if (dias < 0) return 'Não definida';
    if (dias < 60) return dias == 1 ? '1 dia' : '$dias dias';
    final meses = (dias / 30).round();
    return '$meses meses ($dias dias)';
  }

  // -------------------------------------------------------------- Recursos

  Widget _abaRecursos() {
    return CartaoRelatorio(
      titulo: 'Recursos do projeto',
      subtitulo: 'Custo estimado: ${moeda.format(_custoRecursos)}',
      acao: BotaoSecundarioIdv(
        rotulo: 'Gerenciar recursos',
        icone: Icons.tune_rounded,
        aoTocar: _gerenciarRecursos,
      ),
      child: TabelaRelatorio(
        colunas: const ['Recurso', 'Quantidade', 'Cobrança', 'Período', 'Custo estimado'],
        pesos: const [3, 1, 2, 2, 2],
        vazio: 'Nenhum recurso vinculado. Use "Gerenciar recursos".',
        linhas: [
          for (final v in _vinculos)
            [
              CelulaRelatorio(
                _recursos[v.recursoId]?.nome ?? 'Recurso #${v.recursoId}',
                abaixo: _recursos[v.recursoId]?.tipo,
                forte: true,
              ),
              CelulaRelatorio('${v.quantidade}'),
              CelulaRelatorio(
                v.cobranca.rotulo,
                abaixo: v.custoHora == null
                    ? null
                    : '${moeda.format(v.custoHora)}${v.cobranca.sufixo}',
              ),
              CelulaRelatorio(
                dataCurta.format(v.dataAlocacao),
                abaixo: v.dataDesalocacao == null
                    ? 'em uso'
                    : 'até ${dataCurta.format(v.dataDesalocacao!)}',
              ),
              CelulaRelatorio(moeda.format(v.custoEstimado()), forte: true),
            ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Testes

  Widget _abaTestes(bool desktop) {
    final concluidos =
        _testes.where((t) => t.situacao.toLowerCase() == 'concluido').length;
    final pendentes = _testes.length - concluidos;
    final taxa =
        _testes.isEmpty ? 0 : (concluidos * 100 / _testes.length).round();

    final indicadores = [
      IndicadorRelatorio(
          icone: Icons.fact_check_outlined,
          titulo: 'Testes',
          valor: '${_testes.length}',
          detalhe: 'cadastrados no projeto'),
      IndicadorRelatorio(
          icone: Icons.check_circle_outline_rounded,
          titulo: 'Concluídos',
          valor: '$concluidos',
          complemento: '/${_testes.length}',
          detalhe: 'executados com sucesso'),
      IndicadorRelatorio(
          icone: Icons.pending_outlined,
          titulo: 'Pendentes',
          valor: '$pendentes',
          detalhe: 'aguardando execução'),
      IndicadorRelatorio(
          icone: Icons.percent_rounded,
          titulo: 'Progresso',
          valor: '$taxa',
          complemento: '%',
          detalhe: 'dos testes concluídos'),
    ];

    final lista = CartaoRelatorio(
      titulo: 'Testes do projeto',
      acao: BotaoSecundarioIdv(
          rotulo: 'Novo teste', icone: Icons.add_rounded, aoTocar: _novoTeste),
      child: TabelaRelatorio(
        colunas: const ['Teste', 'Situação', ''],
        pesos: const [6, 2, 1],
        vazio: 'Nenhum teste cadastrado. Use "Novo teste".',
        linhas: [
          for (final t in _testes)
            [
              CelulaRelatorio(t.nome, abaixo: t.descricao, forte: true),
              _EtiquetaSituacao(t.situacao),
              _AcoesLinha([
                (Icons.edit_outlined, 'Editar teste', () => _editarTeste(t), false),
                (Icons.delete_outline_rounded, 'Excluir teste',
                    () => _excluirTeste(t), true),
              ]),
            ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _linhaIndicadores(indicadores, desktop),
        const SizedBox(height: 20),
        lista,
      ],
    );
  }

  // ------------------------------------------------------------- Artefatos

  Widget _abaArtefatos() {
    return CartaoRelatorio(
      titulo: 'Documentação e artefatos',
      subtitulo: _documentos.length == 1
          ? '1 documento'
          : '${_documentos.length} documentos',
      acao: _acoes(
        rotulo: 'Novo documento',
        aoCriar: _novoDocumento,
        dicaPagina: 'Abrir a página de documentos (ver, editar e enviar)',
        pagina: DocumentosProjetoScreen(projeto: p),
      ),
      child: TabelaRelatorio(
        colunas: const ['Documento', 'Tipo', 'Criado em', 'Aprovação'],
        pesos: const [4, 2, 2, 2],
        vazio: 'Nenhum documento. Use "Novo documento" para gerar com a IA.',
        linhas: [
          for (final d in _documentos)
            [
              CelulaRelatorio(d.nomeDoArquivo, abaixo: d.descricao, forte: true),
              CelulaRelatorio(_ou(d.tipo, '—')),
              CelulaRelatorio(
                  d.dataCriacao == null ? '—' : dataCurta.format(d.dataCriacao!)),
              d.dataAprovacao == null
                  ? const _Etiqueta('Em revisão', aprovado: false)
                  : const _Etiqueta('Aprovado', aprovado: true),
            ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------- Treinamentos

  Widget _abaTreinamentos() {
    final horas =
        _treinamentos.fold<int>(0, (s, t) => s + (t.duracaoHoras ?? 0));
    return CartaoRelatorio(
      titulo: 'Treinamentos do projeto',
      subtitulo: '${_treinamentos.length} '
          '${_treinamentos.length == 1 ? 'treinamento' : 'treinamentos'}'
          ' · $horas h no total',
      acao: BotaoSecundarioIdv(
          rotulo: 'Novo treinamento',
          icone: Icons.add_rounded,
          aoTocar: _novoTreinamento),
      child: TabelaRelatorio(
        colunas: const ['Treinamento', 'Tipo', 'Período', 'Carga', 'Instrutor', ''],
        pesos: const [3, 2, 2, 1, 2, 2],
        vazio: 'Nenhum treinamento. Use "Novo treinamento".',
        linhas: [
          for (final t in _treinamentos)
            [
              CelulaRelatorio(t.nome, abaixo: t.descricao, forte: true),
              CelulaRelatorio(_ou(t.tipoTreinamento, '—')),
              CelulaRelatorio(
                t.dataInicio == null ? '—' : dataCurta.format(t.dataInicio!),
                abaixo: t.dataTermino == null
                    ? null
                    : 'até ${dataCurta.format(t.dataTermino!)}',
              ),
              CelulaRelatorio(t.duracaoHoras == null ? '—' : '${t.duracaoHoras} h'),
              CelulaRelatorio(_ou(t.instrutor, '—')),
              _AcoesLinha([
                (Icons.how_to_reg_outlined, 'Controle de presença',
                    () => _presenca(t), false),
                (Icons.edit_outlined, 'Editar treinamento',
                    () => _editarTreinamento(t), false),
                (Icons.delete_outline_rounded, 'Excluir treinamento',
                    () => _excluirTreinamento(t), true),
              ]),
            ],
        ],
      ),
    );
  }

  Widget _linhaIndicadores(List<Widget> itens, bool desktop) {
    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final k in itens) ...[k, const SizedBox(height: 12)]],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < itens.length; i++) ...[
          if (i > 0) const SizedBox(width: 18),
          Expanded(child: itens[i]),
        ],
      ],
    );
  }
}

String _ou(String? v, String vazio) =>
    (v == null || v.trim().isEmpty) ? vazio : v.trim();

// =====================================================================
// Peças da tela
// =====================================================================

/// Voltar, nome do projeto, cliente e status.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.projeto, required this.desktop});

  final Projeto projeto;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final status = projeto.statusCalculado;
    final estilo = EstiloStatus.de(status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: desktop ? 6 : 0, right: 10),
          child: IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded,
                color: StyleProjetos.azulEscuro),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                projeto.nomeProjeto,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: desktop
                    ? StyleProjetos.titulo
                    : StyleProjetos.titulo.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Pílula do tamanho do texto (sem alignment, que esticava).
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: estilo.gradiente,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(status,
                        style: StyleProjetos.pill.copyWith(color: estilo.corTexto)),
                  ),
                  Text(
                    _ou(projeto.clienteNome, 'Cliente não informado'),
                    style: StyleProjetos.cardCliente,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Rótulo" pequeno em cima do valor.
class _Info extends StatelessWidget {
  const _Info(this.rotulo, this.valor, {this.largo = false});
  final String rotulo;
  final String valor;
  final bool largo;

  @override
  Widget build(BuildContext context) {
    return _InfoWidget(
      rotulo,
      Text(valor, style: fonteIdv(tamanho: 14, peso: FontWeight.w500, altura: 1.45)),
      largo: largo,
    );
  }
}

class _InfoWidget extends StatelessWidget {
  const _InfoWidget(this.rotulo, this.valor, {this.largo = false});
  final String rotulo;
  final Widget valor;
  final bool largo;

  @override
  Widget build(BuildContext context) {
    final coluna = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rotulo,
            style: fonteIdv(
                tamanho: 12, peso: FontWeight.w500, cor: CoresIdv.textoSecundario)),
        const SizedBox(height: 4),
        valor,
      ],
    );
    return largo ? coluna : ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 120), child: coluna);
  }
}

class _Complexidade extends StatelessWidget {
  const _Complexidade(this.valor);
  final ComplexidadeProjeto? valor;

  @override
  Widget build(BuildContext context) {
    final (texto, fundo, cor) = switch (valor) {
      ComplexidadeProjeto.alta => ('Alta', const Color(0xFFFDECEA), const Color(0xFFB42318)),
      ComplexidadeProjeto.media => ('Média', const Color(0xFFFFF4EC), const Color(0xFFC24A00)),
      ComplexidadeProjeto.baixa => ('Baixa', const Color(0xFFE7F6EC), const Color(0xFF1E6B41)),
      _ => ('Não definida', CoresIdv.azulSuave, StyleProjetos.textoSecundario),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(999)),
      child: Text(texto, style: fonteIdv(tamanho: 12, peso: FontWeight.w600, cor: cor)),
    );
  }
}

class _LinhaData extends StatelessWidget {
  const _LinhaData(this.rotulo, this.data, {this.vazio = 'Não definida'});
  final String rotulo;
  final DateTime? data;
  final String vazio;

  @override
  Widget build(BuildContext context) => _LinhaTexto(
      rotulo, data == null ? vazio : dataCurta.format(data!),
      apagado: data == null);
}

class _LinhaTexto extends StatelessWidget {
  const _LinhaTexto(this.rotulo, this.valor,
      {this.ultima = false, this.apagado = false});
  final String rotulo;
  final String valor;
  final bool ultima;
  final bool apagado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : const Border(bottom: BorderSide(color: StyleProjetos.divisoria)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(rotulo,
                style: fonteIdv(tamanho: 13, cor: CoresIdv.textoSecundario)),
          ),
          Text(valor,
              style: fonteIdv(
                  tamanho: 14,
                  peso: FontWeight.w500,
                  cor: apagado ? CoresIdv.textoSecundario : CoresIdv.texto)),
        ],
      ),
    );
  }
}

/// Pessoa da equipe: avatar com as iniciais e o nome.
class _Pessoa extends StatelessWidget {
  const _Pessoa({required this.nome, required this.ultima});
  final String nome;
  final bool ultima;

  String get _iniciais {
    final partes =
        nome.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final ultimaLetra = partes.length > 1 ? partes.last[0] : '';
    return (partes.first[0] + ultimaLetra).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : const Border(bottom: BorderSide(color: StyleProjetos.divisoria)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: StyleProjetos.azulEscuro, shape: BoxShape.circle),
            child: Text(_iniciais,
                style: fonteIdv(
                    tamanho: 12, peso: FontWeight.w700, cor: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: fonteIdv(tamanho: 14, peso: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _EtiquetaSituacao extends StatelessWidget {
  const _EtiquetaSituacao(this.situacao);
  final String situacao;

  @override
  Widget build(BuildContext context) {
    final concluido = situacao.toLowerCase() == 'concluido';
    return _Etiqueta(concluido ? 'Concluído' : 'Pendente', aprovado: concluido);
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, {required this.aprovado});
  final String texto;
  final bool aprovado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: aprovado ? const Color(0xFFE7F6EC) : const Color(0xFFFFF7A1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(texto,
          style: fonteIdv(
              tamanho: 12,
              peso: FontWeight.w600,
              cor: aprovado ? const Color(0xFF1E6B41) : StyleProjetos.azulEscuro)),
    );
  }
}

class _AvisoFalha extends StatelessWidget {
  const _AvisoFalha();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 20, color: CoresIdv.vermelho),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Não foi possível carregar esta parte. Confira se o back-end '
              'está rodando e tente de novo.',
              style: fonteIdv(tamanho: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ícones de ação no fim da linha (editar, excluir...), com dica.
class _AcoesLinha extends StatelessWidget {
  const _AcoesLinha(this.acoes);

  /// (ícone, dica, ao tocar, é de perigo)
  final List<(IconData, String, VoidCallback, bool)> acoes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final (icone, dica, aoTocar, perigo) in acoes)
          IconButton(
            tooltip: dica,
            onPressed: aoTocar,
            visualDensity: VisualDensity.compact,
            icon: Icon(icone,
                size: 20,
                color: perigo ? CoresIdv.vermelho : StyleProjetos.azulEscuro),
          ),
      ],
    );
  }
}
