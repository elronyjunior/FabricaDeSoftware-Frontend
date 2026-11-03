import 'dart:ui';

import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/providers/projetos_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Os mesmos status que o card calcula (Projeto.statusCalculado).
const _opcoesStatus = ['Em processo', 'Atrasado', 'Concluído'];

const _bordaPilula = Color(0x590F1030);

TextStyle _fonte(
        {double tamanho = 16,
        FontWeight peso = FontWeight.w400,
        Color cor = StyleProjetos.texto}) =>
    GoogleFonts.inter(fontSize: tamanho, fontWeight: peso, color: cor);

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// =====================================================================
// Botão "Filtro" com contador de filtros ativos
// =====================================================================

class BotaoFiltro extends StatelessWidget {
  const BotaoFiltro({super.key});

  /// Abre o popover logo abaixo do botão, numa camada que cobre a janela
  /// inteira (desfoca também o menu lateral).
  void _abrir(BuildContext context) {
    final caixa = context.findRenderObject() as RenderBox?;
    if (caixa == null) return;
    // Retângulo do botão na janela (já considera a escala da tela).
    final ancora = MatrixUtils.transformRect(
        caixa.getTransformTo(null), Offset.zero & caixa.size);
    CamadaModal.abrir(PopoverFiltros(ancora: ancora), fundoClaro: true);
  }

  @override
  Widget build(BuildContext context) {
    final ativos = context.watch<ProjetosProvider>().filtros.ativos;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          shape: const StadiumBorder(
            side: BorderSide(color: StyleProjetos.azulEscuro),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _abrir(context),
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
                color: StyleProjetos.laranja,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$ativos',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

// =====================================================================
// Popover "Filtrar projetos"
// =====================================================================

class PopoverFiltros extends StatefulWidget {
  const PopoverFiltros({super.key, required this.ancora});

  /// Retângulo do botão "Filtro" na janela.
  final Rect ancora;

  @override
  State<PopoverFiltros> createState() => _PopoverFiltrosState();
}

class _PopoverFiltrosState extends State<PopoverFiltros> {
  static const _largura = 480.0;

  late final ProjetosProvider _provider = context.read<ProjetosProvider>();
  late Set<String> _status = {..._provider.filtros.status};
  late DateTime? _conclusaoAte = _provider.filtros.conclusaoAte;
  late String? _tipo = _provider.filtros.tipo;
  late Set<String> _membros = {..._provider.filtros.membros};
  late final _cliente = TextEditingController(text: _provider.filtros.cliente);
  final _buscaMembro = TextEditingController();
  final _focoCliente = FocusNode();
  final _focoMembro = FocusNode();

  /// Campo e sugestões no mesmo grupo de toque: clicar numa sugestão não
  /// tira o foco do campo antes do clique valer.
  final _grupoCliente = Object();
  final _grupoMembro = Object();
  bool _calendarioAberto = false;

  @override
  void initState() {
    super.initState();
    _focoCliente.addListener(() => setState(() {}));
    _focoMembro.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cliente.dispose();
    _buscaMembro.dispose();
    _focoCliente.dispose();
    _focoMembro.dispose();
    super.dispose();
  }

  FiltrosProjeto get _atual => FiltrosProjeto(
        status: _status,
        conclusaoAte: _conclusaoAte,
        tipo: _tipo,
        cliente: _cliente.text.trim(),
        membros: _membros,
      );

  void _filtrar() {
    _provider.aplicarFiltros(_atual);
    CamadaModal.fechar();
  }

  void _limpar() {
    setState(() {
      _status = {};
      _conclusaoAte = null;
      _tipo = null;
      _membros = {};
      _cliente.clear();
      _buscaMembro.clear();
    });
    _provider.aplicarFiltros(FiltrosProjeto.vazio);
  }

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.of(context).size;
    // Como o painel de Novo projeto: preso à direita, quase da altura toda.
    final largura = (tela.width - 32).clamp(0.0, _largura);

    return Stack(
      children: [
        // Clique fora fecha.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: CamadaModal.fechar,
          ),
        ),
        Positioned(
          top: 16,
          bottom: 16,
          right: 16,
          width: largura,
          child: _cartao(),
        ),
      ],
    );
  }

  Widget _cartao() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F0F1030), blurRadius: 30, offset: Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Material(
            color: Colors.white.withOpacity(0.82),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: Colors.white.withOpacity(0.9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 22, 20, 18),
                  child: _cabecalho(),
                ),
                const Divider(height: 1, color: Color(0x1F0F1030)),
                // Campos rolam; o rodapé fica sempre no fim do painel.
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 26, 32, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _linhaStatus(),
                        const SizedBox(height: 24),
                        _pilulaData(),
                        const SizedBox(height: 14),
                        _pilulaTipo(),
                        const SizedBox(height: 14),
                        _pilulaCliente(),
                        const SizedBox(height: 14),
                        _pilulaMembros(),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0x1F0F1030)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 32, 18),
                  child: _rodape(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cabecalho() => Row(
        children: [
          Expanded(
            child: Text('Filtrar projetos',
                style: _fonte(tamanho: 22, peso: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Fechar',
            onPressed: CamadaModal.fechar,
            icon: const Icon(Icons.close_rounded,
                size: 26, color: StyleProjetos.laranja),
          ),
        ],
      );

  Widget _linhaStatus() => Row(
        children: [
          Text('Status:', style: _fonte(tamanho: 16, peso: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _opcoesStatus)
                  _ChipStatus(
                    rotulo: s,
                    marcado: _status.contains(s),
                    aoTocar: () => setState(() {
                      _status = {..._status};
                      if (!_status.remove(s)) _status.add(s);
                    }),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _pilulaData() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pilulaDataCampo(),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _calendarioAberto
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: CalendarioDiaIdv(
                      selecionado: _conclusaoAte,
                      aoEscolher: (d) => setState(() {
                        _conclusaoAte = d;
                        if (d != null) _calendarioAberto = false;
                      }),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      );

  Widget _pilulaDataCampo() => _Pilula(
        aoTocar: () => setState(() => _calendarioAberto = !_calendarioAberto),
        icone: Icons.calendar_month_rounded,
        filho: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Data: '),
            TextSpan(
              text: _conclusaoAte == null
                  ? 'qualquer conclusão'
                  : 'Conclusão até ${_data(_conclusaoAte!)}',
              style: _conclusaoAte == null
                  ? _fonte(cor: StyleProjetos.textoSecundario)
                  : null,
            ),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _fonte(),
        ),
      );

  Widget _pilulaTipo() {
    final tipos = _provider.tiposDisponiveis;
    return PopupMenuButton<String?>(
      tooltip: '',
      position: PopupMenuPosition.under,
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      constraints: const BoxConstraints(minWidth: 300, maxHeight: 320),
      onSelected: (v) => setState(() => _tipo = v),
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
            value: null, child: Text('Todos', style: _fonte())),
        for (final t in tipos)
          PopupMenuItem<String?>(value: t, child: Text(t, style: _fonte())),
      ],
      child: _Pilula(
        icone: Icons.keyboard_arrow_down_rounded,
        filho: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Tipo: '),
            TextSpan(
              text: _tipo ?? 'Todos',
              style: _tipo == null
                  ? _fonte(cor: StyleProjetos.textoSecundario)
                  : null,
            ),
          ]),
          style: _fonte(),
        ),
      ),
    );
  }

  Widget _pilulaCliente() {
    final termo = _cliente.text.trim().toLowerCase();
    final sugestoes = !_focoCliente.hasFocus
        ? const <String>[]
        : _provider.clientesDisponiveis
            .where((c) =>
                c.toLowerCase().contains(termo) && c.toLowerCase() != termo)
            .take(5)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Pilula(
          icone: Icons.search_rounded,
          aoTocar: _focoCliente.requestFocus,
          filho: _CampoNaPilula(
            rotulo: 'Cliente: ',
            controle: _cliente,
            foco: _focoCliente,
            grupo: _grupoCliente,
            hint: 'todos',
            aoMudar: (_) => setState(() {}),
            aoEnviar: () {
              if (sugestoes.isNotEmpty) _escolherCliente(sugestoes.first);
            },
          ),
        ),
        if (sugestoes.isNotEmpty)
          TapRegion(
            groupId: _grupoCliente,
            child: _Sugestoes(itens: sugestoes, aoEscolher: _escolherCliente),
          ),
      ],
    );
  }

  Widget _pilulaMembros() {
    final termo = _buscaMembro.text.trim().toLowerCase();
    final sugestoes = !_focoMembro.hasFocus
        ? const <MembroProjeto>[]
        : _provider.membrosDisponiveis
            .where((m) =>
                !_membros.contains(m.id) &&
                m.nome.toLowerCase().contains(termo))
            .take(5)
            .toList();

    void escolher(MembroProjeto m) => setState(() {
          _membros = {..._membros, m.id};
          _buscaMembro.clear();
          _focoMembro.requestFocus(); // continua escolhendo
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Pilula(
          icone: Icons.search_rounded,
          aoTocar: _focoMembro.requestFocus,
          filho: _CampoNaPilula(
            rotulo: 'Membros: ',
            controle: _buscaMembro,
            foco: _focoMembro,
            grupo: _grupoMembro,
            hint: 'pesquisar pessoa',
            aoMudar: (_) => setState(() {}),
            aoEnviar: () {
              if (sugestoes.isNotEmpty) escolher(sugestoes.first);
            },
          ),
        ),
        if (sugestoes.isNotEmpty)
          TapRegion(
            groupId: _grupoMembro,
            child: _Sugestoes(
              itens: [for (final m in sugestoes) m.nome],
              aoEscolher: (nome) =>
                  escolher(sugestoes.firstWhere((m) => m.nome == nome)),
            ),
          ),
        if (_membros.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in _membros)
                _ChipMembro(
                  nome: _provider.nomeDoMembro(id),
                  aoRemover: () =>
                      setState(() => _membros = {..._membros}..remove(id)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _escolherCliente(String cliente) => setState(() {
        _cliente.text = cliente;
        _cliente.selection = TextSelection.collapsed(offset: cliente.length);
        _focoCliente.unfocus();
      });

  Widget _rodape() => Row(
        children: [
          TextButton.icon(
            onPressed: _limpar,
            style: TextButton.styleFrom(
                foregroundColor: StyleProjetos.textoSecundario),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text('Limpar filtro',
                style: _fonte(tamanho: 14, cor: StyleProjetos.textoSecundario)),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _filtrar,
            style: ElevatedButton.styleFrom(
              backgroundColor: StyleProjetos.azulEscuro,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(150, 50),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text('Filtrar',
                style: _fonte(
                    tamanho: 15, peso: FontWeight.w600, cor: Colors.white)),
          ),
        ],
      );
}

/// Pílula com contorno fino e ícone à direita (campos do filtro).
class _Pilula extends StatelessWidget {
  const _Pilula({required this.filho, required this.icone, this.aoTocar});

  final Widget filho;
  final IconData icone;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final conteudo = Container(
      height: 54,
      padding: const EdgeInsets.only(left: 20, right: 16),
      decoration: ShapeDecoration(
        color: Colors.white.withOpacity(0.55),
        shape: const StadiumBorder(side: BorderSide(color: _bordaPilula)),
      ),
      child: Row(
        children: [
          Expanded(child: filho),
          const SizedBox(width: 10),
          Icon(icone, size: 22, color: StyleProjetos.azulEscuro),
        ],
      ),
    );
    if (aoTocar == null) return conteudo;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: aoTocar, child: conteudo),
    );
  }
}

/// "Rótulo: campo" dentro da pílula.
class _CampoNaPilula extends StatelessWidget {
  const _CampoNaPilula({
    required this.rotulo,
    required this.controle,
    required this.foco,
    required this.grupo,
    required this.hint,
    required this.aoMudar,
    required this.aoEnviar,
  });

  final String rotulo;
  final TextEditingController controle;
  final FocusNode foco;
  final Object grupo;
  final String hint;
  final ValueChanged<String> aoMudar;
  final VoidCallback aoEnviar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(rotulo, style: _fonte()),
        Expanded(
          child: TextField(
            controller: controle,
            focusNode: foco,
            groupId: grupo,
            onChanged: aoMudar,
            // Enter escolhe a primeira sugestão.
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => aoEnviar(),
            maxLines: 1,
            style: _fonte(),
            strutStyle: const StrutStyle(forceStrutHeight: true, height: 1.2),
            cursorColor: StyleProjetos.azulEscuro,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: _fonte(cor: StyleProjetos.textoSecundario),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sugestões que aparecem embaixo de uma pílula de busca.
class _Sugestoes extends StatelessWidget {
  const _Sugestoes({required this.itens, required this.aoEscolher});

  final List<String> itens;
  final ValueChanged<String> aoEscolher;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x240F1030)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in itens)
            InkWell(
              onTap: () => aoEscolher(item),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Text(item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _fonte(tamanho: 14)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chip de status: laranja quando marcado, contorno cinza quando não.
class _ChipStatus extends StatelessWidget {
  const _ChipStatus(
      {required this.rotulo, required this.marcado, required this.aoTocar});

  final String rotulo;
  final bool marcado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: aoTocar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: ShapeDecoration(
            color: marcado
                ? StyleProjetos.laranja.withOpacity(0.08)
                : Colors.white.withOpacity(0.5),
            shape: StadiumBorder(
              side: BorderSide(
                  color: marcado ? StyleProjetos.laranja : _bordaPilula),
            ),
          ),
          child: Text(
            rotulo,
            style: _fonte(
              tamanho: 14,
              peso: marcado ? FontWeight.w600 : FontWeight.w400,
              cor: marcado
                  ? StyleProjetos.laranja
                  : StyleProjetos.textoSecundario,
            ),
          ),
        ),
      ),
    );
  }
}

/// Membro escolhido no filtro (toque no X remove).
class _ChipMembro extends StatelessWidget {
  const _ChipMembro({required this.nome, required this.aoRemover});

  final String nome;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 3, bottom: 3),
      decoration: ShapeDecoration(
        color: Colors.white.withOpacity(0.5),
        shape: const StadiumBorder(side: BorderSide(color: _bordaPilula)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(nome,
              style: _fonte(tamanho: 13, cor: StyleProjetos.textoSecundario)),
          InkWell(
            onTap: aoRemover,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.close_rounded,
                  size: 14, color: StyleProjetos.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Campo de pesquisa por nome do projeto
// =====================================================================

class CampoPesquisa extends StatefulWidget {
  const CampoPesquisa({super.key});

  @override
  State<CampoPesquisa> createState() => _CampoPesquisaState();
}

class _CampoPesquisaState extends State<CampoPesquisa> {
  // Começa com o filtro atual: o campo é recriado quando o layout muda
  // (ex.: ao redimensionar a janela) e não pode aparecer vazio com o
  // filtro ainda ativo.
  late final _controller =
      TextEditingController(text: context.read<ProjetosProvider>().filtroNome);
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focado = _foco.hasFocus;

    // A borda fica no Container (e não no TextField) para o campo ocupar
    // exatamente a mesma altura da pílula "Filtro".
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
              // Campo de uma linha, da altura do texto, centralizado pela
              // Row na mesma linha do ícone (como o texto do "Filtro").
              child: TextField(
                controller: _controller,
                focusNode: _foco,
                onChanged: (v) =>
                    context.read<ProjetosProvider>().setFiltroNome(v),
                style: StyleProjetos.controle,
                strutStyle:
                    const StrutStyle(forceStrutHeight: true, height: 1.2),
                cursorColor: StyleProjetos.azulEscuro,
                cursorHeight: 16,
                maxLines: 1,
                // Campo de uma linha só: Enter não quebra linha.
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n')),
                ],
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
