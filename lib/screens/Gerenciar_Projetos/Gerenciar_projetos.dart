import 'package:fabrica_software_app/Widgets/Barra_lateral/Barra_Lateral.dart';
import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_conversacional/modal_conversacional.dart';
import 'package:fabrica_software_app/models/projeto.dart';
import 'package:fabrica_software_app/providers/projetos_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'components/Card_Projeto.dart';
import 'components/escala_design.dart';
import 'components/filtro.dart';

/// Quantos cards entram a cada vez que a rolagem chega perto do fim.
const int _lote = 12;

class GerenciarProjetos extends StatefulWidget {
  const GerenciarProjetos({super.key});

  @override
  State<GerenciarProjetos> createState() => _GerenciarProjetosState();
}

class _GerenciarProjetosState extends State<GerenciarProjetos> {
  final _rolagem = ScrollController();
  int _quantidade = _lote;
  int _total = 0;
  bool _ordenarAZ = false;

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(_aoRolar);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjetosProvider>().carregarProjetos();
    });
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  // ---------------- Rolagem infinita ----------------

  void _aoRolar() {
    final posicao = _rolagem.position;
    if (posicao.pixels >= posicao.maxScrollExtent - 300) _carregarMais();
  }

  void _carregarMais() {
    if (_quantidade >= _total) return;
    setState(() => _quantidade += _lote);
  }

  /// Se os cards ainda não enchem a tela, não há como rolar:
  /// então já carrega o próximo lote.
  void _garantirTelaCheia() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_rolagem.hasClients) return;
      if (_rolagem.position.maxScrollExtent <= 0) _carregarMais();
    });
  }

  void _voltarAoTopo() {
    _quantidade = _lote;
    if (_rolagem.hasClients) _rolagem.jumpTo(0);
  }

  void _recarregar() {
    setState(_voltarAoTopo);
    context.read<ProjetosProvider>().carregarProjetos();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    // O menu lateral é desenhado pelo LayoutPrincipal (main.dart).
    final desktop = LayoutPrincipal.menuFixo(context);

    return Scaffold(
      drawer: BarraLateral.drawer(context),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: StyleProjetos.gradienteFundo),
        child: SafeArea(
          child: desktop
              // Desktop: desenha na escala do Figma e amplia tudo
              // proporcionalmente. A largura base desconta o espaço do menu,
              // para a escala ser a mesma usada pelo menu.
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
    return Padding(
      padding: desktop
          ? const EdgeInsets.fromLTRB(25, 62, 36, 0)
          : const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- Cabeçalho ----------------
          Row(
            children: [
              if (!desktop)
                Builder(
                  builder: (ctx) => IconButton(
                    icon:
                        const Icon(Icons.menu, color: StyleProjetos.azulEscuro),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              Expanded(
                child: Text(
                  'Gestão de Projetos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: desktop
                      ? StyleProjetos.titulo
                      : StyleProjetos.titulo.copyWith(fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Padding(
                padding: EdgeInsets.only(top: desktop ? 10 : 0),
                child: _BotaoNovoProjeto(
                  onPressed: () => abrirModalCriacao(context),
                ),
              ),
            ],
          ),
          // Alinha a barra "Lista de Projetos" com o 2º ícone do menu.
          SizedBox(height: desktop ? 82 : 28),

          // ---------------- Lista ----------------
          Expanded(
            child: Consumer<ProjetosProvider>(
              builder: (context, provider, _) {
                final projetos = List<Projeto>.of(provider.projetos ?? []);
                if (_ordenarAZ) {
                  projetos.sort((a, b) => a.nomeProjeto
                      .toLowerCase()
                      .compareTo(b.nomeProjeto.toLowerCase()));
                }
                _total = projetos.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BarraFerramentas(
                      total: projetos.length,
                      ordenarAZ: _ordenarAZ,
                      onOrdenar: () => setState(() {
                        _ordenarAZ = !_ordenarAZ;
                        _voltarAoTopo();
                      }),
                      onRecarregar: _recarregar,
                    ),
                    const SizedBox(height: 31),
                    Expanded(child: _grade(provider, projetos)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _grade(ProjetosProvider provider, List<Projeto> projetos) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: StyleProjetos.laranja),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Não foi possível carregar os projetos: ${provider.error}',
                textAlign: TextAlign.center, style: StyleProjetos.contador),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _recarregar,
              style:
                  TextButton.styleFrom(foregroundColor: StyleProjetos.laranja),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (projetos.isEmpty) {
      return Center(
        child: Text(
          'Nenhum projeto encontrado. Ajuste os filtros ou crie um novo projeto.',
          textAlign: TextAlign.center,
          style: StyleProjetos.cardDescricao.copyWith(fontSize: 14),
        ),
      );
    }

    final visiveis = projetos.take(_quantidade).toList();
    final temMais = visiveis.length < projetos.length;
    if (temMais) _garantirTelaCheia();

    return LayoutBuilder(
      builder: (context, constraints) {
        final colunas = constraints.maxWidth > 1050
            ? 3
            : constraints.maxWidth > 680
                ? 2
                : 1;

        // A área de rolagem é um pouco maior que o espaço da grade (folga dos
        // lados e em cima), com o mesmo valor de padding por dentro: os cards
        // ficam no mesmo lugar, mas o card ampliado no hover e a sombra dele
        // não são mais cortados pela borda da rolagem.
        return _ComFolga(
          folga: _folgaGrade,
          child: CustomScrollView(
            controller: _rolagem,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    _folgaGrade, _folgaGrade, _folgaGrade, 0),
                sliver: SliverToBoxAdapter(
                  child: _GradeCards(
                    projetos: visiveis,
                    colunas: colunas,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: temMais
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: StyleProjetos.laranja,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void abrirModalCriacao(BuildContext context) {
  // Formulário conversacional (mesmo formulário e mesmo envio do wizard).
  abrirModalConversacional(context).then((_) {
    // Recarrega a lista ao fechar o modal (cancelar ou finalizar),
    // para que um projeto recém-criado apareça sem sair da tela.
    if (context.mounted) {
      context.read<ProjetosProvider>().carregarProjetos();
    }
  });
}

// =====================================================================
// Componentes da tela
// =====================================================================

class _BotaoNovoProjeto extends StatelessWidget {
  const _BotaoNovoProjeto({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: StyleProjetos.gradienteLaranja,
        borderRadius: BorderRadius.circular(StyleProjetos.botaoRaio),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 20, color: Colors.white),
        label: Text('Novo Projeto', style: StyleProjetos.botao),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(146, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StyleProjetos.botaoRaio)),
        ),
      ),
    );
  }
}

/// "Lista de Projetos" + Filtro + Pesquisa + ordenar/recarregar + contador.
class _BarraFerramentas extends StatelessWidget {
  const _BarraFerramentas({
    required this.total,
    required this.ordenarAZ,
    required this.onOrdenar,
    required this.onRecarregar,
  });

  final int total;
  final bool ordenarAZ;
  final VoidCallback onOrdenar;
  final VoidCallback onRecarregar;

  @override
  Widget build(BuildContext context) {
    final contador = Text(
      total == 1 ? '1 projeto encontrado' : '$total projetos encontrados',
      style: StyleProjetos.contador,
    );

    final acoes = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BotaoFerramenta(
          dica: ordenarAZ ? 'Remover ordenação' : 'Ordenar de A a Z',
          ativo: ordenarAZ,
          onTap: onOrdenar,
          child: const _IconeAZ(),
        ),
        const SizedBox(width: 6),
        _BotaoFerramenta(
          dica: 'Recarregar projetos',
          onTap: onRecarregar,
          child: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
        contador,
      ],
    );

    final titulo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Lista de Projetos', style: StyleProjetos.subtitulo),
        const SizedBox(width: 20),
        const BotaoFiltro(),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [titulo, acoes],
              ),
              const SizedBox(height: 14),
              const CampoPesquisa(),
            ],
          );
        }

        return Row(
          children: [
            titulo,
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 397),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: CampoPesquisa(),
                  ),
                ),
              ),
            ),
            acoes,
          ],
        );
      },
    );
  }
}

/// Área clicável de 30x30 (mesma altura do filtro e da pesquisa),
/// com o ícone centralizado. Todos os ícones da barra usam o mesmo tamanho.
class _BotaoFerramenta extends StatelessWidget {
  const _BotaoFerramenta({
    required this.dica,
    required this.onTap,
    required this.child,
    this.ativo = false,
  });

  final String dica;
  final VoidCallback onTap;
  final Widget child;
  final bool ativo;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: dica,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: SizedBox.square(
          dimension: StyleProjetos.controleAltura,
          child: Center(
            child: IconTheme(
              data: IconThemeData(
                size: StyleProjetos.ferramentaIcone,
                color: ativo ? StyleProjetos.laranja : StyleProjetos.azulEscuro,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ícone "A sobre Z + seta para baixo", igual ao da referência.
/// Herda tamanho e cor do IconTheme do _BotaoFerramenta.
class _IconeAZ extends StatelessWidget {
  const _IconeAZ();

  @override
  Widget build(BuildContext context) {
    final tema = IconTheme.of(context);
    final tamanho = tema.size ?? 22;
    final letra = GoogleFonts.inter(
      fontSize: tamanho * 0.45,
      fontWeight: FontWeight.w700,
      color: tema.color,
      height: 1,
    );

    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('A', style: letra),
              SizedBox(height: tamanho * 0.05),
              Text('Z', style: letra),
            ],
          ),
          Icon(Icons.arrow_downward, size: tamanho * 0.62, color: tema.color),
        ],
      ),
    );
  }
}

/// Folga em volta da grade para o card ampliado (hover) e a sombra caberem.
const double _folgaGrade = 22;

/// Estende o [child] [folga] px para os lados e para cima, além do espaço que
/// ele recebeu (sem mudar o layout do resto da tela).
class _ComFolga extends StatelessWidget {
  const _ComFolga({required this.folga, required this.child});

  final double folga;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => OverflowBox(
        alignment: Alignment.bottomCenter,
        minWidth: c.maxWidth + folga * 2,
        maxWidth: c.maxWidth + folga * 2,
        minHeight: c.maxHeight + folga,
        maxHeight: c.maxHeight + folga,
        child: child,
      ),
    );
  }
}

/// Grade de cards em que o card com o mouse por cima é desenhado por último,
/// ficando acima dos vizinhos enquanto está ampliado.
class _GradeCards extends StatefulWidget {
  const _GradeCards({required this.projetos, required this.colunas});

  final List<Projeto> projetos;
  final int colunas;

  @override
  State<_GradeCards> createState() => _GradeCardsState();
}

class _GradeCardsState extends State<_GradeCards> {
  static const _espacoX = 16.0;
  static const _espacoY = 15.0;

  Object? _emCima;

  Object _chave(Projeto p, int i) => p.id ?? 'i$i';

  @override
  Widget build(BuildContext context) {
    final projetos = widget.projetos;
    final colunas = widget.colunas;
    final linhas = (projetos.length / colunas).ceil();
    const altura = StyleProjetos.cardAltura;

    return LayoutBuilder(
      builder: (context, c) {
        final largura = (c.maxWidth - _espacoX * (colunas - 1)) / colunas;

        Widget card(int i) {
          final p = projetos[i];
          final chave = _chave(p, i);
          return Positioned(
            key: ValueKey(chave),
            left: (i % colunas) * (largura + _espacoX),
            top: (i ~/ colunas) * (altura + _espacoY),
            width: largura,
            height: altura,
            child: ProjectCard(
              projeto: p,
              aoPassarMouse: (dentro) => setState(() {
                if (dentro) {
                  _emCima = chave;
                } else if (_emCima == chave) {
                  _emCima = null;
                }
              }),
            ),
          );
        }

        final indices = List<int>.generate(projetos.length, (i) => i);
        // O card em hover vai para o fim da lista (desenhado por cima). As
        // chaves mantêm o estado de cada card ao mudar a ordem.
        final emCima =
            indices.where((i) => _chave(projetos[i], i) == _emCima).toList();
        final ordem = [
          ...indices.where((i) => !emCima.contains(i)),
          ...emCima,
        ];

        return SizedBox(
          height: linhas == 0 ? 0 : linhas * altura + (linhas - 1) * _espacoY,
          child: Stack(
            clipBehavior: Clip.none,
            children: [for (final i in ordem) card(i)],
          ),
        );
      },
    );
  }
}
