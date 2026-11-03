import 'dart:ui';

import 'package:fabrica_software_app/Widgets/Barra_lateral/Barra_Lateral.dart';
import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/components/escala_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// =====================================================================
// Tela de gestão em tabela (Clientes, Usuários...) no mesmo padrão da tela
// de Projetos: título, botão laranja, barra com Filtro, pesquisa, ordenar,
// recarregar e contador, e a lista com rolagem infinita (sem paginação).
// =====================================================================

/// Coluna da tabela: título, peso na largura e alinhamento.
class ColunaGestao {
  const ColunaGestao(this.titulo,
      {this.flex = 1, this.alinhamento = Alignment.centerLeft});

  final String titulo;
  final int flex;
  final Alignment alinhamento;
}

/// Ações de uma linha (ver, editar, excluir).
class AcoesGestao {
  const AcoesGestao({this.aoVer, this.aoEditar, this.aoExcluir});
  final VoidCallback? aoVer;
  final VoidCallback? aoEditar;
  final VoidCallback? aoExcluir;
}

enum _Ordem { padrao, az, za }

class PaginaGestao<T> extends StatefulWidget {
  const PaginaGestao({
    super.key,
    required this.titulo,
    required this.rotuloNovo,
    required this.aoNovo,
    required this.tituloLista,
    required this.singular,
    required this.plural,
    this.feminino = false,
    required this.itens,
    required this.carregando,
    required this.erro,
    required this.aoRecarregar,
    required this.nome,
    required this.textoBusca,
    this.colunas = const [],
    this.celulas,
    this.acoes,
    this.card,
    this.colunasGrade = 3,
    this.rotuloFiltro,
    this.valorFiltro,
  });

  final String titulo;
  final String rotuloNovo;
  final VoidCallback aoNovo;
  final String tituloLista;

  /// "cliente" / "clientes" (contador e mensagens).
  final String singular;
  final String plural;

  /// Concorda os textos com o item ("encontradas", "Nenhuma").
  final bool feminino;

  final List<T> itens;
  final bool carregando;
  final String? erro;
  final VoidCallback aoRecarregar;

  /// Nome usado na ordenação A-Z.
  final String Function(T item) nome;

  /// Texto em que a pesquisa procura.
  final String Function(T item) textoBusca;

  final List<ColunaGestao> colunas;

  /// Uma célula por coluna, menos a de ações (a última, desenhada aqui).
  final List<Widget> Function(T item)? celulas;
  final AcoesGestao Function(T item)? acoes;

  /// Modo grade: em vez da tabela, desenha um card por item (3 por linha
  /// no desktop, como os cards de Projetos).
  final Widget Function(T item)? card;

  /// Máximo de cards por linha na grade (menos em telas estreitas).
  final int colunasGrade;

  /// Filtro por um campo (ex.: "Setor"): as opções vêm dos próprios itens.
  final String? rotuloFiltro;
  final String? Function(T item)? valorFiltro;

  @override
  State<PaginaGestao<T>> createState() => _PaginaGestaoState<T>();
}

class _PaginaGestaoState<T> extends State<PaginaGestao<T>> {
  /// Quantas linhas entram a cada vez que a rolagem chega perto do fim.
  static const _lote = 20;

  final _rolagem = ScrollController();
  final _busca = TextEditingController();
  int _quantidade = _lote;
  _Ordem _ordem = _Ordem.padrao;
  Set<String> _filtro = {};
  bool _rolado = false;

  /// Card com o mouse por cima (desenhado por cima dos vizinhos).
  int? _cardEmCima;

  String get _o => widget.feminino ? 'a' : 'o';
  String get _a => widget.feminino ? 'a' : '';

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(_aoRolar);
  }

  @override
  void dispose() {
    _rolagem.dispose();
    _busca.dispose();
    super.dispose();
  }

  void _aoRolar() {
    final p = _rolagem.position;
    final rolado = p.pixels > 2;
    if (rolado != _rolado) setState(() => _rolado = rolado);
    if (p.pixels >= p.maxScrollExtent - 300) _carregarMais();
  }

  void _carregarMais() {
    if (_quantidade >= _filtrados.length) return;
    setState(() => _quantidade += _lote);
  }

  void _voltarAoTopo() {
    _quantidade = _lote;
    if (_rolagem.hasClients) _rolagem.jumpTo(0);
  }

  static String _semAcento(String texto) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const para = 'aaaaaeeeeiiiiooooouuuucn';
    final saida = StringBuffer();
    for (final c in texto.trim().toLowerCase().split('')) {
      final i = de.indexOf(c);
      saida.write(i >= 0 ? para[i] : c);
    }
    return saida.toString();
  }

  List<T> get _filtrados {
    final termo = _semAcento(_busca.text);
    final lista = widget.itens.where((item) {
      if (termo.isNotEmpty &&
          !_semAcento(widget.textoBusca(item)).contains(termo)) {
        return false;
      }
      if (_filtro.isNotEmpty) {
        final valor = widget.valorFiltro?.call(item);
        if (valor == null || !_filtro.contains(valor)) return false;
      }
      return true;
    }).toList();

    if (_ordem != _Ordem.padrao) {
      lista.sort((a, b) {
        final r =
            _semAcento(widget.nome(a)).compareTo(_semAcento(widget.nome(b)));
        return _ordem == _Ordem.az ? r : -r;
      });
    }
    return lista;
  }

  List<String> get _opcoesFiltro {
    final valores = <String>{};
    for (final item in widget.itens) {
      final v = widget.valorFiltro?.call(item)?.trim();
      if (v != null && v.isNotEmpty) valores.add(v);
    }
    return valores.toList()
      ..sort((a, b) => _semAcento(a).compareTo(_semAcento(b)));
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
    final itens = _filtrados;

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
                  widget.titulo,
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
                child: BotaoNovoGestao(
                    rotulo: widget.rotuloNovo, aoTocar: widget.aoNovo),
              ),
            ],
          ),
          SizedBox(height: desktop ? 82 : 28),

          // ---------------- Barra de ferramentas ----------------
          _barraFerramentas(itens.length),
          const SizedBox(height: 22),

          // ---------------- Tabela ----------------
          if (widget.card == null) ...[
            _cabecalhoTabela(),
            const Divider(height: 1, color: Color(0x1F0F1030)),
          ] else
            const SizedBox(height: 9),
          Expanded(child: _lista(itens)),
        ],
      ),
    );
  }

  Widget _barraFerramentas(int total) {
    final contador = Text(
      total == 1
          ? '1 ${widget.singular} encontrad$_o'
          : '$total ${widget.plural} encontrad${_o}s',
      style: StyleProjetos.contador,
    );

    final acoes = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BotaoFerramenta(
          dica: switch (_ordem) {
            _Ordem.padrao => 'Ordenar de A a Z',
            _Ordem.az => 'Ordenar de Z a A',
            _Ordem.za => 'Voltar à ordem padrão',
          },
          ativo: _ordem != _Ordem.padrao,
          aoTocar: () => setState(() {
            _ordem = _Ordem.values[(_ordem.index + 1) % _Ordem.values.length];
            _voltarAoTopo();
          }),
          child: _IconeAZ(invertido: _ordem == _Ordem.za),
        ),
        const SizedBox(width: 6),
        _BotaoFerramenta(
          dica: 'Recarregar',
          aoTocar: () {
            setState(_voltarAoTopo);
            widget.aoRecarregar();
          },
          child: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
        contador,
      ],
    );

    final titulo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.tituloLista, style: StyleProjetos.subtitulo),
        if (widget.valorFiltro != null) ...[
          const SizedBox(width: 20),
          _BotaoFiltro(ativos: _filtro.length, aoTocar: _abrirFiltro),
        ],
      ],
    );

    final pesquisa = CampoPesquisaGestao(
      controle: _busca,
      aoMudar: (_) => setState(_voltarAoTopo),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 820) {
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
            pesquisa,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: pesquisa,
                ),
              ),
            ),
          ),
          acoes,
        ],
      );
    });
  }

  Widget _cabecalhoTabela() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          for (final coluna in widget.colunas)
            Expanded(
              flex: coluna.flex,
              child: Align(
                alignment: coluna.alinhamento,
                child: Text(coluna.titulo,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: StyleProjetos.texto)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lista(List<T> itens) {
    if (widget.carregando && widget.itens.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: StyleProjetos.laranja));
    }
    if (widget.erro != null) {
      return _mensagem(
          'Não foi possível carregar ${_o}s ${widget.plural}: ${widget.erro}',
          comBotao: true);
    }
    if (itens.isEmpty) {
      return _mensagem(widget.itens.isEmpty
          ? 'Nenhum$_a ${widget.singular} cadastrad$_o.'
          : 'Nenhum$_a ${widget.singular} encontrad$_o. Ajuste a pesquisa ou o filtro.');
    }

    final visiveis = itens.take(_quantidade).toList();
    final temMais = visiveis.length < itens.length;
    if (temMais) {
      // Lista curta demais para rolar: já carrega o próximo lote.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _rolagem.hasClients &&
            _rolagem.position.maxScrollExtent <= 0) {
          _carregarMais();
        }
      });
    }

    // Ao rolar, as linhas esmaecem na borda de cima (como em Projetos).
    final lista = TweenAnimationBuilder<double>(
      tween: Tween(end: _rolado ? 1 : 0),
      duration: const Duration(milliseconds: 220),
      builder: (context, t, lista) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (area) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(1 - t), Colors.white],
          stops: [0, (28 / area.height).clamp(0.0, 1.0)],
        ).createShader(area),
        child: lista,
      ),
      child: widget.card == null
          ? _tabela(visiveis, temMais)
          : _grade(visiveis, temMais),
    );
    if (widget.card == null) return lista;

    // Na grade, a área de rolagem é um pouco maior que o espaço dela (folga
    // dos lados e em cima, com o mesmo padding por dentro): o card ampliado
    // no hover e a sombra dele não são cortados (igual a Projetos).
    return LayoutBuilder(
      builder: (context, c) => OverflowBox(
        alignment: Alignment.bottomCenter,
        minWidth: c.maxWidth + _folgaGrade * 2,
        maxWidth: c.maxWidth + _folgaGrade * 2,
        minHeight: c.maxHeight + _folgaGrade,
        maxHeight: c.maxHeight + _folgaGrade,
        child: lista,
      ),
    );
  }

  static const _folgaGrade = 22.0;
  static const _espacoGrade = 24.0;

  Widget _rodapeCarregando(bool temMais) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: temMais
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: StyleProjetos.laranja))
              : const SizedBox.shrink(),
        ),
      );

  Widget _tabela(List<T> visiveis, bool temMais) {
    return ListView.builder(
      controller: _rolagem,
      padding: const EdgeInsets.only(bottom: 28),
      itemCount: visiveis.length + 1,
      itemBuilder: (context, i) {
        if (i == visiveis.length) return _rodapeCarregando(temMais);
        final item = visiveis[i];
        return _LinhaGestao(
          colunas: widget.colunas,
          celulas: widget.celulas?.call(item) ?? const [],
          acoes: widget.acoes?.call(item) ?? const AcoesGestao(),
        );
      },
    );
  }

  /// Cards em linhas de 3 (2 ou 1 em telas menores), como em Projetos.
  Widget _grade(List<T> visiveis, bool temMais) {
    return LayoutBuilder(builder: (context, c) {
      final largura = c.maxWidth - _folgaGrade * 2;
      // Cada card precisa de pelo menos 240 px; no máximo [colunasGrade].
      final colunas = ((largura + _espacoGrade) / (240 + _espacoGrade))
          .floor()
          .clamp(1, widget.colunasGrade);
      final larguraCard = (largura - _espacoGrade * (colunas - 1)) / colunas;
      final linhas = (visiveis.length / colunas).ceil();
      return ListView.builder(
        controller: _rolagem,
        padding: const EdgeInsets.fromLTRB(
            _folgaGrade, _folgaGrade, _folgaGrade, 28),
        itemCount: linhas + 1,
        itemBuilder: (context, i) {
          if (i == linhas) return _rodapeCarregando(temMais);
          final indices = [
            for (var col = 0; col < colunas; col++)
              if (i * colunas + col < visiveis.length) i * colunas + col,
          ];
          // O card em hover vai para o fim (desenhado por cima dos vizinhos).
          final ordem = [
            ...indices.where((k) => k != _cardEmCima),
            ...indices.where((k) => k == _cardEmCima),
          ];
          return Padding(
            padding: const EdgeInsets.only(bottom: _espacoGrade),
            child: SizedBox(
              height: StyleProjetos.cardAltura,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final k in ordem)
                    Positioned(
                      key: ValueKey(widget.nome(visiveis[k]) + '#$k'),
                      left: (k % colunas) * (larguraCard + _espacoGrade),
                      top: 0,
                      width: larguraCard,
                      height: StyleProjetos.cardAltura,
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _cardEmCima = k),
                        onExit: (_) {
                          if (_cardEmCima == k) {
                            setState(() => _cardEmCima = null);
                          }
                        },
                        child: widget.card!(visiveis[k]),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _mensagem(String texto, {bool comBotao = false}) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto,
                textAlign: TextAlign.center,
                style: StyleProjetos.cardDescricao.copyWith(fontSize: 14)),
            if (comBotao)
              TextButton(
                onPressed: widget.aoRecarregar,
                style: TextButton.styleFrom(
                    foregroundColor: StyleProjetos.laranja),
                child: const Text('Tentar novamente'),
              ),
          ],
        ),
      );

  void _abrirFiltro() {
    CamadaModal.abrir(
      _PainelFiltro(
        titulo: 'Filtrar ${widget.plural}',
        rotulo: widget.rotuloFiltro ?? 'Filtro',
        opcoes: _opcoesFiltro,
        selecionados: _filtro,
        aoFiltrar: (escolhidos) => setState(() {
          _filtro = escolhidos;
          _voltarAoTopo();
        }),
      ),
    );
  }
}

// =====================================================================
// Linha da tabela
// =====================================================================

class _LinhaGestao extends StatefulWidget {
  const _LinhaGestao(
      {required this.colunas, required this.celulas, required this.acoes});

  final List<ColunaGestao> colunas;
  final List<Widget> celulas;
  final AcoesGestao acoes;

  @override
  State<_LinhaGestao> createState() => _LinhaGestaoState();
}

class _LinhaGestaoState extends State<_LinhaGestao> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.acoes;
    final celulas = [
      ...widget.celulas,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a.aoVer != null)
            _Acao(icone: Icons.visibility, dica: 'Ver', aoTocar: a.aoVer!),
          if (a.aoEditar != null)
            _Acao(icone: Icons.edit, dica: 'Editar', aoTocar: a.aoEditar!),
          if (a.aoExcluir != null)
            _Acao(
                icone: Icons.delete,
                dica: 'Excluir',
                cor: const Color(0xFFD62A1E),
                aoTocar: a.aoExcluir!),
        ],
      ),
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        // De branco invisível para branco: Colors.transparent é preto
        // invisível e fazia a linha passar por um cinza escuro no hover.
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_hover ? 0.5 : 0),
          border: const Border(bottom: BorderSide(color: Color(0x1A0F1030))),
        ),
        child: Row(
          children: [
            for (var i = 0; i < widget.colunas.length; i++)
              Expanded(
                flex: widget.colunas[i].flex,
                child: Align(
                  alignment: widget.colunas[i].alinhamento,
                  child: i < celulas.length ? celulas[i] : const SizedBox(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Acao extends StatelessWidget {
  const _Acao({
    required this.icone,
    required this.dica,
    required this.aoTocar,
    this.cor = StyleProjetos.azulEscuro,
  });

  final IconData icone;
  final String dica;
  final VoidCallback aoTocar;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: dica,
      child: InkResponse(
        onTap: aoTocar,
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: Icon(icone, size: 20, color: cor),
        ),
      ),
    );
  }
}

// =====================================================================
// Peças da tabela usadas pelas telas (texto, avatar, etiqueta)
// =====================================================================

/// Texto de célula no padrão da tabela.
class TextoCelula extends StatelessWidget {
  const TextoCelula(this.texto, {super.key, this.secundario = false});
  final String texto;
  final bool secundario;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 13,
          color:
              secundario ? StyleProjetos.textoSecundario : StyleProjetos.texto,
        ),
      );
}

/// Avatar redondo com as iniciais e um degradê escolhido pelo nome (o mesmo
/// nome tem sempre a mesma cor) + o nome ao lado.
class NomeComAvatar extends StatelessWidget {
  const NomeComAvatar(this.nome, {super.key});
  final String nome;

  static const _degrades = [
    [StyleProjetos.azulEscuro, Color(0xFF4A4E6E)],
    [Color(0xFF1E4D2B), Color(0xFF6BAA70)],
    [Color(0xFFD0507E), Color(0xFFF2B6CB)],
    [StyleProjetos.laranja, StyleProjetos.laranjaClaro],
    [Color(0xFF3D4BA0), Color(0xFFA9B4F0)],
  ];

  String get _iniciais {
    final partes =
        nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (partes.first[0] + ultima).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cores = _degrades[
        nome.codeUnits.fold<int>(0, (a, b) => a + b) % _degrades.length];
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cores,
            ),
          ),
          child: Text(_iniciais,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: StyleProjetos.texto)),
        ),
      ],
    );
  }
}

/// Etiqueta colorida (setor, tipo de conta). Sem [cor], a cor é escolhida
/// pelo texto (o mesmo texto tem sempre a mesma cor).
class EtiquetaGestao extends StatelessWidget {
  const EtiquetaGestao(this.texto, {super.key, this.fundo, this.corTexto});

  final String texto;
  final Color? fundo;
  final Color? corTexto;

  static const _paleta = [
    (Color(0xFFA9B4F0), StyleProjetos.azulEscuro),
    (Color(0xFF7DC08A), StyleProjetos.azulEscuro),
    (Color(0xFFC9456F), Colors.white),
    (Color(0xFFFFB27A), StyleProjetos.azulEscuro),
    (Color(0xFF7FC6D6), StyleProjetos.azulEscuro),
    (Color(0xFFE3C46B), StyleProjetos.azulEscuro),
  ];

  @override
  Widget build(BuildContext context) {
    final (corFundo, corLetra) = fundo != null
        ? (fundo!, corTexto ?? StyleProjetos.azulEscuro)
        : _paleta[texto.toLowerCase().codeUnits.fold<int>(0, (a, b) => a + b) %
            _paleta.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: StyleProjetos.pill.copyWith(color: corLetra)),
    );
  }
}

// =====================================================================
// Barra: botão novo, filtro, pesquisa, ferramentas
// =====================================================================

class BotaoNovoGestao extends StatelessWidget {
  const BotaoNovoGestao(
      {super.key, required this.rotulo, required this.aoTocar});
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: StyleProjetos.gradienteLaranja,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ElevatedButton.icon(
        onPressed: aoTocar,
        icon: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
        label: Text(rotulo, style: StyleProjetos.botao),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_alt,
                      size: 18, color: StyleProjetos.laranja),
                  const SizedBox(width: 6),
                  Text('Filtro', style: StyleProjetos.controle),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
        if (ativos > 0)
          Positioned(
            top: -10,
            right: -6,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: StyleProjetos.laranja, shape: BoxShape.circle),
              child: Text('$ativos',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
            ),
          ),
      ],
    );
  }
}

class CampoPesquisaGestao extends StatefulWidget {
  const CampoPesquisaGestao(
      {super.key, required this.controle, required this.aoMudar});
  final TextEditingController controle;
  final ValueChanged<String> aoMudar;

  @override
  State<CampoPesquisaGestao> createState() => _CampoPesquisaGestaoState();
}

class _CampoPesquisaGestaoState extends State<CampoPesquisaGestao> {
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focado = _foco.hasFocus;
    return GestureDetector(
      onTap: _foco.requestFocus,
      child: Container(
        height: StyleProjetos.controleAltura,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StyleProjetos.controleAltura / 2),
          border: Border.all(
            color: focado ? StyleProjetos.laranja : StyleProjetos.azulEscuro,
            width: focado ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: StyleProjetos.azulEscuro),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.controle,
                focusNode: _foco,
                onChanged: widget.aoMudar,
                style: StyleProjetos.controle,
                strutStyle:
                    const StrutStyle(forceStrutHeight: true, height: 1.2),
                cursorColor: StyleProjetos.azulEscuro,
                cursorHeight: 16,
                maxLines: 1,
                inputFormatters: [LengthLimitingTextInputFormatter(80)],
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Pesquisa',
                  hintStyle: StyleProjetos.controle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoFerramenta extends StatelessWidget {
  const _BotaoFerramenta({
    required this.dica,
    required this.aoTocar,
    required this.child,
    this.ativo = false,
  });

  final String dica;
  final VoidCallback aoTocar;
  final Widget child;
  final bool ativo;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: dica,
      child: InkResponse(
        onTap: aoTocar,
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

class _IconeAZ extends StatelessWidget {
  const _IconeAZ({this.invertido = false});
  final bool invertido;

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
              Text(invertido ? 'Z' : 'A', style: letra),
              SizedBox(height: tamanho * 0.05),
              Text(invertido ? 'A' : 'Z', style: letra),
            ],
          ),
          Icon(Icons.arrow_downward, size: tamanho * 0.62, color: tema.color),
        ],
      ),
    );
  }
}

// =====================================================================
// Painel de filtro (mesmo visual do filtro de projetos)
// =====================================================================

class _PainelFiltro extends StatefulWidget {
  const _PainelFiltro({
    required this.titulo,
    required this.rotulo,
    required this.opcoes,
    required this.selecionados,
    required this.aoFiltrar,
  });

  final String titulo;
  final String rotulo;
  final List<String> opcoes;
  final Set<String> selecionados;
  final ValueChanged<Set<String>> aoFiltrar;

  @override
  State<_PainelFiltro> createState() => _PainelFiltroState();
}

class _PainelFiltroState extends State<_PainelFiltro> {
  late Set<String> _escolhidos = {...widget.selecionados};

  TextStyle _fonte(
          {double tamanho = 16,
          FontWeight peso = FontWeight.w400,
          Color cor = StyleProjetos.texto}) =>
      GoogleFonts.inter(fontSize: tamanho, fontWeight: peso, color: cor);

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.of(context).size;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: CamadaModal.fechar),
        ),
        Positioned(
          top: 16,
          bottom: 16,
          right: 16,
          width: (tela.width - 32).clamp(0.0, 480.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x1F0F1030),
                    blurRadius: 30,
                    offset: Offset(0, 12)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Material(
                  // Opaco: o fundo escuro da camada não muda a cor do painel.
                  color: const Color(0xFFF8F9FC),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 22, 20, 18),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(widget.titulo,
                                  style: _fonte(
                                      tamanho: 22, peso: FontWeight.w700)),
                            ),
                            IconButton(
                              tooltip: 'Fechar',
                              onPressed: CamadaModal.fechar,
                              icon: const Icon(Icons.close_rounded,
                                  size: 26, color: StyleProjetos.laranja),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0x1F0F1030)),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 26, 32, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${widget.rotulo}:',
                                  style: _fonte(peso: FontWeight.w500)),
                              const SizedBox(height: 12),
                              if (widget.opcoes.isEmpty)
                                Text('Nenhuma opção disponível.',
                                    style: _fonte(
                                        tamanho: 14,
                                        cor: StyleProjetos.textoSecundario))
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final o in widget.opcoes)
                                      _chip(o, _escolhidos.contains(o)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0x1F0F1030)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 32, 18),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _escolhidos = {});
                                widget.aoFiltrar({});
                              },
                              style: TextButton.styleFrom(
                                  foregroundColor:
                                      StyleProjetos.textoSecundario),
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              label: Text('Limpar filtro',
                                  style: _fonte(
                                      tamanho: 14,
                                      cor: StyleProjetos.textoSecundario)),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () {
                                widget.aoFiltrar(_escolhidos);
                                CamadaModal.fechar();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: StyleProjetos.azulEscuro,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(150, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: Text('Filtrar',
                                  style: _fonte(
                                      tamanho: 15,
                                      peso: FontWeight.w600,
                                      cor: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String rotulo, bool marcado) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() {
          _escolhidos = {..._escolhidos};
          if (!_escolhidos.remove(rotulo)) _escolhidos.add(rotulo);
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: ShapeDecoration(
            color: marcado
                ? StyleProjetos.laranja.withOpacity(0.08)
                : Colors.white.withOpacity(0.5),
            shape: StadiumBorder(
              side: BorderSide(
                  color: marcado
                      ? StyleProjetos.laranja
                      : const Color(0x590F1030)),
            ),
          ),
          child: Text(rotulo,
              style: _fonte(
                tamanho: 14,
                peso: marcado ? FontWeight.w600 : FontWeight.w400,
                cor: marcado
                    ? StyleProjetos.laranja
                    : StyleProjetos.textoSecundario,
              )),
        ),
      ),
    );
  }
}
