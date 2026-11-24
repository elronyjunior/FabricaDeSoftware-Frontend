import 'package:fabrica_software_app/Widgets/Barra_lateral/Barra_Lateral.dart';
import 'package:fabrica_software_app/Widgets/Gestao/pagina_gestao.dart';
import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/components/escala_design.dart';
import 'package:fabrica_software_app/screens/Relatorio/components/filtros_relatorio.dart';
import 'package:fabrica_software_app/screens/Relatorio/components/pecas_relatorio.dart';
import 'package:fabrica_software_app/screens/Relatorio/dados_relatorio.dart';
import 'package:fabrica_software_app/screens/Relatorio/exportar_relatorio.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// =====================================================================
// Relatórios no padrão das telas de gestão: título e "Exportar" (PDF),
// barra com Filtro, pesquisa e período, abas e os painéis de cada aba.
// =====================================================================

class RelatoriosScreen extends StatelessWidget {
  const RelatoriosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DadosRelatorioProvider()..carregar(),
      child: const _TelaRelatorios(),
    );
  }
}

enum _Aba {
  resumo('Resumo geral'),
  projetos('Projetos'),
  testes('Testes'),
  treinamentos('Treinamentos');

  const _Aba(this.rotulo);
  final String rotulo;
}

class _TelaRelatorios extends StatefulWidget {
  const _TelaRelatorios();

  @override
  State<_TelaRelatorios> createState() => _TelaRelatoriosState();
}

class _TelaRelatoriosState extends State<_TelaRelatorios> {
  final _busca = TextEditingController();
  _Aba _aba = _Aba.resumo;
  bool _exportando = false;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _exportar(DadosRelatorioProvider dados) async {
    setState(() => _exportando = true);
    try {
      await exportarRelatorioPdf(dados);
    } catch (e) {
      if (mounted) avisar(context, 'Não foi possível gerar o PDF: $e');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _abrirFiltros(DadosRelatorioProvider dados) async {
    final novos = await abrirFiltrosRelatorio(
      context,
      atuais: dados.filtros,
      clientes: dados.opcoesClientes,
      tipos: dados.opcoesTipos,
    );
    if (novos != null) dados.aplicarFiltros(novos);
  }

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
    final dados = context.watch<DadosRelatorioProvider>();

    return Padding(
      padding: desktop
          ? const EdgeInsets.fromLTRB(25, 62, 36, 0)
          : const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- Cabeçalho ----------------
          Row(
            children: [
              if (!desktop)
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: StyleProjetos.azulEscuro),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              Expanded(
                child: Text('Relatórios',
                    style: desktop
                        ? StyleProjetos.titulo
                        : StyleProjetos.titulo.copyWith(fontSize: 24)),
              ),
              Padding(
                padding: EdgeInsets.only(top: desktop ? 10 : 0),
                child: _BotaoExportar(
                  carregando: _exportando,
                  aoTocar: dados.temDados ? () => _exportar(dados) : null,
                ),
              ),
            ],
          ),
          SizedBox(height: desktop ? 44 : 20),

          // ---------------- Ferramentas ----------------
          LayoutBuilder(builder: (context, c) {
            final filtro = _BotaoFiltro(
                ativos: dados.filtros.ativos, aoTocar: () => _abrirFiltros(dados));
            // Mesmo padrão das telas de gestão: título + Filtro à esquerda,
            // pesquisa no centro e as ferramentas à direita.
            final titulo = Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Indicadores', style: StyleProjetos.subtitulo),
              const SizedBox(width: 20),
              filtro,
            ]);
            final pesquisa = CampoPesquisaGestao(
                controle: _busca, aoMudar: dados.buscar);
            final periodo = _SeletorPeriodo(
              atual: dados.filtros.periodo,
              aoMudar: dados.mudarPeriodo,
            );
            final recarregar = Tooltip(
              message: 'Recarregar',
              child: InkResponse(
                onTap: dados.carregando ? null : dados.carregar,
                radius: 18,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.refresh, color: StyleProjetos.azulEscuro),
                ),
              ),
            );
            if (c.maxWidth < 860) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [titulo, SizedBox(width: 260, child: pesquisa), periodo, recarregar],
              );
            }
            return Row(children: [
              titulo,
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 397),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: pesquisa,
                    ),
                  ),
                ),
              ),
              periodo,
              const SizedBox(width: 8),
              recarregar,
            ]);
          }),
          const SizedBox(height: 22),

          // ---------------- Abas ----------------
          _Abas(atual: _aba, aoMudar: (a) => setState(() => _aba = a)),
          const SizedBox(height: 6),

          Expanded(child: _corpo(dados)),
        ],
      ),
    );
  }

  Widget _corpo(DadosRelatorioProvider dados) {
    if (dados.carregando && !dados.temDados) {
      return const Center(
          child: CircularProgressIndicator(color: StyleProjetos.laranja));
    }
    if (dados.erro != null && !dados.temDados) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Não foi possível carregar os relatórios.',
                style: StyleProjetos.cardTitulo),
            const SizedBox(height: 4),
            Text(dados.erro!, style: StyleProjetos.cardRodape),
            const SizedBox(height: 10),
            TextButton(
              onPressed: dados.carregar,
              child: Text('Tentar de novo',
                  style: StyleProjetos.cardTitulo
                      .copyWith(color: StyleProjetos.laranja, fontSize: 14)),
            ),
          ],
        ),
      );
    }

    final aba = switch (_aba) {
      _Aba.resumo => _AbaResumo(dados: dados),
      _Aba.projetos => _AbaProjetos(dados: dados),
      _Aba.testes => _AbaTestes(dados: dados),
      _Aba.treinamentos => _AbaTreinamentos(dados: dados),
    };

    return SingleChildScrollView(
      // Uma rolagem por aba: cada aba abre do topo.
      key: ValueKey(_aba),
      // Folga para a sombra dos cartões não ser cortada.
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dados.indisponiveis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                'Não foi possível carregar: ${dados.indisponiveis.join(', ')}. '
                'Os outros números estão completos.',
                style: StyleProjetos.cardRodape
                    .copyWith(color: const Color(0xFFD62A1E)),
              ),
            ),
          aba,
        ],
      ),
    );
  }
}

// =====================================================================
// Abas
// =====================================================================

/// Linha de painéis: lado a lado no desktop, empilhados em tela estreita.
///
/// [esticar] deixa todos com a altura do mais alto; sem ele (ex.: gráfico
/// ao lado de uma tabela longa) cada um fica com a própria altura.
Widget _linha(List<Widget> filhos,
    {List<int>? pesos, double quebra = 860, bool esticar = true}) {
  return LayoutBuilder(builder: (context, c) {
    if (c.maxWidth < quebra) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < filhos.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            filhos[i],
          ],
        ],
      );
    }
    final linha = Row(
      crossAxisAlignment:
          esticar ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < filhos.length; i++) ...[
          if (i > 0) const SizedBox(width: 18),
          Expanded(flex: pesos?[i] ?? 1, child: filhos[i]),
        ],
      ],
    );
    return esticar ? IntrinsicHeight(child: linha) : linha;
  });
}

const _espaco = SizedBox(height: 18);

String _periodoTexto(DadosRelatorioProvider d) {
  final f = d.filtros;
  if (f.periodo == PeriodoRapido.personalizado) {
    final (i, fim) = f.intervalo;
    return '${i == null ? 'início' : dataCurta.format(i)} a '
        '${fim == null ? 'hoje' : dataCurta.format(fim)}';
  }
  return f.periodo == PeriodoRapido.tudo
      ? 'todo o período'
      : 'últimos ${f.periodo.rotulo}';
}

class _AbaResumo extends StatelessWidget {
  const _AbaResumo({required this.dados});
  final DadosRelatorioProvider dados;

  @override
  Widget build(BuildContext context) {
    final projetos = dados.projetos;
    final status = dados.porStatus;
    final taxa = dados.taxaTestes;
    final linhaTempo = dados.linhaDoTempo(projetos.map(DadosRelatorioProvider.dataDo));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _linha([
          IndicadorRelatorio(
            destaque: true,
            icone: FontAwesomeIcons.sackDollar,
            titulo: 'Orçamento estimado',
            valor: moeda.format(dados.orcamentoTotal),
            detalhe: 'Soma de ${projetos.length} projetos · ${_periodoTexto(dados)}',
          ),
          IndicadorRelatorio(
            icone: FontAwesomeIcons.diagramProject,
            titulo: 'Total de projetos',
            valor: '${projetos.length}',
            detalhe: '${status['Em processo']} em processo · '
                '${status['Atrasado']} atrasados',
          ),
          IndicadorRelatorio(
            icone: FontAwesomeIcons.peopleGroup,
            titulo: 'Custo de recursos',
            valor: dinheiroCurto(dados.custoRecursos),
            detalhe: '${dados.alocacoes.length} alocações de recursos',
          ),
          IndicadorRelatorio(
            icone: FontAwesomeIcons.clipboardCheck,
            titulo: 'Testes concluídos',
            valor: taxa == null ? '—' : '${taxa.round()}',
            complemento: taxa == null ? null : '%',
            detalhe: taxa == null
                ? 'Nenhum teste no filtro'
                : '${dados.testesPorSituacao['concluido']} de ${dados.testes.length} testes',
          ),
        ], quebra: 900),
        _espaco,
        _linha([
          CartaoRelatorio(
            titulo: 'Projetos iniciados',
            subtitulo: dados.linhaPorAno
                ? 'Por ano, pela data de início'
                : 'Por mês, pela data de início',
            altura: 300,
            child: GraficoColunas(itens: linhaTempo),
          ),
          CartaoRelatorio(
            titulo: 'Status dos projetos',
            subtitulo: 'Concluído, atrasado (passou do prazo) ou em processo',
            altura: 300,
            child: GraficoRosca(
              rotuloCentro: 'projetos',
              fatias: [
                for (final s in statusProjeto)
                  Fatia(s, (status[s] ?? 0).toDouble(), corDoStatus(s)),
              ],
            ),
          ),
        ], pesos: [3, 2]),
        _espaco,
        _linha([
          CartaoRelatorio(
            titulo: 'Projetos recentes',
            subtitulo: 'Os mais novos no filtro atual',
            child: _TabelaProjetos(projetos: projetos.take(6).toList()),
          ),
          CartaoRelatorio(
            titulo: 'Custo de recursos',
            subtitulo: 'Projetos que mais gastam com recursos',
            child: BarrasHorizontais(
              itens: dados.custoPorProjeto(),
              formatar: dinheiroCurto,
            ),
          ),
        ], pesos: [3, 2]),
      ],
    );
  }
}

class _AbaProjetos extends StatelessWidget {
  const _AbaProjetos({required this.dados});
  final DadosRelatorioProvider dados;

  @override
  Widget build(BuildContext context) {
    final complexidade = dados.porComplexidade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _linha([
          CartaoRelatorio(
            titulo: 'Orçamento por cliente',
            subtitulo: 'Soma do orçamento estimado dos projetos',
            child: BarrasHorizontais(
              itens: dados.orcamentoPorCliente(),
              formatar: dinheiroCurto,
            ),
          ),
          CartaoRelatorio(
            titulo: 'Complexidade',
            subtitulo: 'Projetos por nível de complexidade',
            child: GraficoRosca(
              rotuloCentro: 'projetos',
              fatias: [
                Fatia('Baixa', complexidade['Baixa']!.toDouble(), azulClaro),
                Fatia('Média', complexidade['Média']!.toDouble(),
                    StyleProjetos.azulEscuro),
                Fatia('Alta', complexidade['Alta']!.toDouble(),
                    StyleProjetos.laranja),
              ],
            ),
          ),
        ]),
        _espaco,
        CartaoRelatorio(
          titulo: 'Todos os projetos',
          subtitulo: '${dados.projetos.length} no filtro atual',
          child: _TabelaProjetos(projetos: dados.projetos, comComplexidade: true),
        ),
      ],
    );
  }
}

class _TabelaProjetos extends StatelessWidget {
  const _TabelaProjetos({required this.projetos, this.comComplexidade = false});
  final List projetos;
  final bool comComplexidade;

  @override
  Widget build(BuildContext context) {
    String data(DateTime? d) => d == null ? '—' : dataCurta.format(d);
    return TabelaRelatorio(
      colunas: [
        'Projeto',
        'Início',
        'Prazo',
        if (comComplexidade) 'Complexidade',
        'Status',
        'Orçamento',
      ],
      pesos: [3, 2, 2, if (comComplexidade) 2, 2, 2],
      linhas: [
        for (final p in projetos)
          [
            CelulaRelatorio(p.nomeProjeto, abaixo: p.clienteNome, forte: true),
            CelulaRelatorio(data(DadosRelatorioProvider.dataDo(p))),
            CelulaRelatorio(data(p.dataFinalPrevisto)),
            if (comComplexidade)
              CelulaRelatorio(p.complexidade == null
                  ? '—'
                  : rotuloComplexidade(p.complexidade)),
            EtiquetaStatusRelatorio(p.statusCalculado),
            CelulaRelatorio(p.orcamentoEstimado == null
                ? '—'
                : dinheiroCurto(p.orcamentoEstimado)),
          ],
      ],
    );
  }
}

class _AbaTestes extends StatelessWidget {
  const _AbaTestes({required this.dados});
  final DadosRelatorioProvider dados;

  static const _cores = {
    'concluido': StyleProjetos.azulEscuro,
    'em_progresso': azulClaro,
    'pendente': Color(0xFFC9CCDA),
    'falha': Color(0xFFD62A1E),
  };

  @override
  Widget build(BuildContext context) {
    final testes = dados.testes;
    final por = dados.testesPorSituacao;
    final taxa = dados.taxaTestes;

    // Por projeto: total, concluídos e falhas.
    final porProjeto = <int, List<int>>{};
    for (final t in testes) {
      final l = porProjeto.putIfAbsent(t.projetoId, () => [0, 0, 0]);
      l[0]++;
      if (t.situacao == 'concluido') l[1]++;
      if (t.situacao == 'falha') l[2]++;
    }
    final ordem = porProjeto.entries.toList()
      ..sort((a, b) => b.value[0].compareTo(a.value[0]));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _linha([
          IndicadorRelatorio(
            destaque: true,
            icone: FontAwesomeIcons.clipboardCheck,
            titulo: 'Testes concluídos',
            valor: taxa == null ? '—' : '${taxa.round()}',
            complemento: taxa == null ? null : '%',
            detalhe: '${por['concluido']} de ${testes.length} testes',
          ),
          IndicadorRelatorio(
            icone: FontAwesomeIcons.listCheck,
            titulo: 'Total de testes',
            valor: '${testes.length}',
            detalhe: 'Em ${porProjeto.length} projetos',
          ),
          IndicadorRelatorio(
            icone: FontAwesomeIcons.hourglassHalf,
            titulo: 'Pendentes ou em execução',
            valor: '${por['pendente']! + por['em_progresso']!}',
            detalhe: '${por['em_progresso']} em execução agora',
          ),
          IndicadorRelatorio(
            icone: FontAwesomeIcons.triangleExclamation,
            titulo: 'Com falha',
            valor: '${por['falha']}',
            detalhe: 'Precisam de correção',
          ),
        ], quebra: 900),
        _espaco,
        _linha([
          CartaoRelatorio(
            titulo: 'Situação dos testes',
            child: GraficoRosca(
              rotuloCentro: 'testes',
              fatias: [
                for (final e in rotulosSituacaoTeste.entries)
                  Fatia(e.value, (por[e.key] ?? 0).toDouble(), _cores[e.key]!),
              ],
            ),
          ),
          CartaoRelatorio(
            titulo: 'Testes por projeto',
            subtitulo: 'Quanto de cada projeto já foi testado',
            child: TabelaRelatorio(
              vazio: 'Nenhum teste no filtro atual.',
              colunas: const ['Projeto', 'Testes', 'Falhas', 'Concluído'],
              pesos: const [3, 1, 1, 3],
              linhas: [
                for (final e in ordem)
                  [
                    CelulaRelatorio(dados.nomeDoProjeto(e.key), forte: true),
                    CelulaRelatorio('${e.value[0]}'),
                    CelulaRelatorio('${e.value[2]}'),
                    _Progresso(e.value[1] / e.value[0]),
                  ],
              ],
            ),
          ),
        ], pesos: [2, 3]),
      ],
    );
  }
}

class _AbaTreinamentos extends StatelessWidget {
  const _AbaTreinamentos({required this.dados});
  final DadosRelatorioProvider dados;

  @override
  Widget build(BuildContext context) {
    final lista = [...dados.treinamentos]..sort((a, b) =>
        (b.dataInicio ?? DateTime(1900)).compareTo(a.dataInicio ?? DateTime(1900)));
    final concluidos = dados.treinamentosConcluidos;
    final agora = DateTime.now();
    final emAndamento = lista
        .where((t) =>
            t.dataInicio != null &&
            t.dataInicio!.isBefore(agora) &&
            !dados.treinamentoConcluido(t))
        .length;
    String data(DateTime? d) => d == null ? '—' : dataCurta.format(d);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _linha([
          IndicadorRelatorio(
            destaque: true,
            icone: FontAwesomeIcons.graduationCap,
            titulo: 'Treinamentos concluídos',
            valor: '$concluidos',
            complemento: '/${lista.length}',
            detalhe: 'Terminaram antes de hoje',
          ),
          IndicadorRelatorio(
            icone: FontAwesomeIcons.personChalkboard,
            titulo: 'Em andamento',
            valor: '$emAndamento',
            detalhe: 'Já começaram e ainda não terminaram',
          ),
          IndicadorRelatorio(
            icone: FontAwesomeIcons.clock,
            titulo: 'Carga horária',
            valor: '${dados.horasTreinamento}',
            complemento: ' h',
            detalhe: 'Soma de todos os treinamentos',
          ),
        ], quebra: 900),
        _espaco,
        _linha([
          CartaoRelatorio(
            titulo: 'Treinamentos por período',
            subtitulo: 'Pela data de início',
            altura: 300,
            child: GraficoColunas(
                itens: dados.linhaDoTempo(lista.map((t) => t.dataInicio))),
          ),
          CartaoRelatorio(
            titulo: 'Treinamentos',
            subtitulo: 'Do mais recente para o mais antigo',
            child: TabelaRelatorio(
              vazio: 'Nenhum treinamento no filtro atual.',
              colunas: const ['Treinamento', 'Instrutor', 'Período', 'Horas'],
              pesos: const [3, 2, 3, 1],
              linhas: [
                for (final t in lista.take(8))
                  [
                    CelulaRelatorio(t.nome,
                        abaixo: dados.nomeDoProjeto(t.projetoId), forte: true),
                    CelulaRelatorio(t.instrutor ?? '—'),
                    CelulaRelatorio(
                        '${data(t.dataInicio)} a ${data(t.dataTermino)}'),
                    CelulaRelatorio(t.duracaoHoras == null ? '—' : '${t.duracaoHoras} h'),
                  ],
              ],
            ),
          ),
        ], pesos: [2, 3], esticar: false),
      ],
    );
  }
}

// =====================================================================
// Peças da barra
// =====================================================================

class _Progresso extends StatelessWidget {
  const _Progresso(this.valor);
  final double valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: valor.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: trilho,
              valueColor: const AlwaysStoppedAnimation(StyleProjetos.laranja),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text('${(valor * 100).round()}%',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: StyleProjetos.texto)),
        ),
      ],
    );
  }
}

class _Abas extends StatelessWidget {
  const _Abas({required this.atual, required this.aoMudar});
  final _Aba atual;
  final ValueChanged<_Aba> aoMudar;

  @override
  Widget build(BuildContext context) {
    return AbasSublinhadas(
      rotulos: [for (final a in _Aba.values) a.rotulo],
      atual: atual.index,
      aoMudar: (i) => aoMudar(_Aba.values[i]),
    );
  }
}

/// Pílulas de período rápido (como o Mensal/Anual do exemplo).
class _SeletorPeriodo extends StatelessWidget {
  const _SeletorPeriodo({required this.atual, required this.aoMudar});
  final PeriodoRapido atual;
  final ValueChanged<PeriodoRapido> aoMudar;

  @override
  Widget build(BuildContext context) {
    final opcoes = [
      PeriodoRapido.dias30,
      PeriodoRapido.meses3,
      PeriodoRapido.meses12,
      PeriodoRapido.tudo,
      if (atual == PeriodoRapido.personalizado) PeriodoRapido.personalizado,
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x260F1030)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in opcoes)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => aoMudar(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: p == atual ? StyleProjetos.azulEscuro : null,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    p.rotulo,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          p == atual ? FontWeight.w600 : FontWeight.w500,
                      color: p == atual ? Colors.white : StyleProjetos.texto,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botão "Filtro" com o número de filtros em uso (igual às telas de gestão).
class _BotaoFiltro extends StatelessWidget {
  const _BotaoFiltro({required this.ativos, required this.aoTocar});
  final int ativos;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          shape: const StadiumBorder(
              side: BorderSide(color: StyleProjetos.azulEscuro)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: aoTocar,
            child: Container(
              height: StyleProjetos.controleAltura,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FontAwesomeIcons.filter,
                      size: 13, color: StyleProjetos.laranja),
                  const SizedBox(width: 8),
                  Text('Filtro', style: StyleProjetos.controle),
                ],
              ),
            ),
          ),
        ),
        if (ativos > 0)
          Positioned(
            right: -6,
            top: -7,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: StyleProjetos.laranja, shape: BoxShape.circle),
              child: Text('$ativos',
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
      ],
    );
  }
}

class _BotaoExportar extends StatelessWidget {
  const _BotaoExportar({required this.carregando, required this.aoTocar});
  final bool carregando;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: StyleProjetos.gradienteLaranja,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ElevatedButton.icon(
        onPressed: carregando ? null : aoTocar,
        icon: carregando
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(FontAwesomeIcons.fileArrowDown,
                size: 16, color: Colors.white),
        label: Text('Exportar PDF', style: StyleProjetos.botao),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(172, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}
