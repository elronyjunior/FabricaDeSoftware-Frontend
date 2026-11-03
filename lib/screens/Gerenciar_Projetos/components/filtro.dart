import 'package:fabrica_software_app/providers/projetos_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

typedef FiltrosProjeto = ({String tipo, String status, String cliente});

const FiltrosProjeto _semFiltros =
    (tipo: 'Todos', status: 'Todos', cliente: '');

// Os mesmos status que o card calcula (Projeto.statusCalculado).
const _opcoesStatus = ['Todos', 'Em processo', 'Concluído', 'Atrasado'];

// =====================================================================
// Botão "Filtro" com contador de filtros ativos
// =====================================================================

class BotaoFiltro extends StatefulWidget {
  const BotaoFiltro({super.key});

  @override
  State<BotaoFiltro> createState() => _BotaoFiltroState();
}

class _BotaoFiltroState extends State<BotaoFiltro> {
  FiltrosProjeto _filtros = _semFiltros;

  int get _ativos =>
      (_filtros.tipo != 'Todos' ? 1 : 0) +
      (_filtros.status != 'Todos' ? 1 : 0) +
      (_filtros.cliente.isNotEmpty ? 1 : 0);

  Future<void> _abrir() async {
    final resultado = await showDialog<FiltrosProjeto>(
      context: context,
      builder: (_) => _DialogFiltros(inicial: _filtros),
    );
    if (resultado == null || !mounted) return;

    setState(() => _filtros = resultado);
    final provider = context.read<ProjetosProvider>();
    provider.setFiltroTipo(resultado.tipo);
    provider.setFiltroStatus(resultado.status);
    provider.setFiltroCliente(resultado.cliente);
  }

  @override
  Widget build(BuildContext context) {
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
            onTap: _abrir,
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
        if (_ativos > 0)
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
                '$_ativos',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _DialogFiltros extends StatefulWidget {
  const _DialogFiltros({required this.inicial});
  final FiltrosProjeto inicial;

  @override
  State<_DialogFiltros> createState() => _DialogFiltrosState();
}

class _DialogFiltrosState extends State<_DialogFiltros> {
  late String _tipo = widget.inicial.tipo;
  late String _status = widget.inicial.status;
  late final _cliente = TextEditingController(text: widget.inicial.cliente);

  @override
  void dispose() {
    _cliente.dispose();
    super.dispose();
  }

  InputDecoration _decoracao({String? hint, IconData? icone}) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: icone == null ? null : Icon(icone, size: 18),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: StyleProjetos.laranja, width: 1.5),
        ),
      );

  Widget _rotulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          texto,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: StyleProjetos.textoSecundario,
          ),
        ),
      );

  Widget _dropdown(
      List<String> opcoes, String valor, ValueChanged<String> aoMudar) {
    return DropdownButtonFormField<String>(
      // Valor que não está mais entre as opções volta para "Todos".
      value: opcoes.contains(valor) ? valor : opcoes.first,
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      decoration: _decoracao(),
      style: StyleProjetos.pesquisa.copyWith(fontSize: 14),
      items: [
        for (final o in opcoes) DropdownMenuItem(value: o, child: Text(o)),
      ],
      onChanged: (v) {
        if (v != null) aoMudar(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.filter_alt, color: StyleProjetos.laranja),
          const SizedBox(width: 8),
          Text('Filtros', style: StyleProjetos.subtitulo),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rotulo('Tipo'),
            _dropdown(
              // Tipos que existem nos projetos carregados.
              ['Todos', ...context.read<ProjetosProvider>().tiposDisponiveis],
              _tipo,
              (v) => setState(() => _tipo = v),
            ),
            const SizedBox(height: 16),
            _rotulo('Status'),
            _dropdown(
                _opcoesStatus, _status, (v) => setState(() => _status = v)),
            const SizedBox(height: 16),
            _rotulo('Cliente'),
            TextField(
              controller: _cliente,
              style: StyleProjetos.pesquisa.copyWith(fontSize: 14),
              decoration:
                  _decoracao(hint: 'Nome do cliente', icone: Icons.business),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _semFiltros),
          style: TextButton.styleFrom(
              foregroundColor: StyleProjetos.textoSecundario),
          child: const Text('Limpar filtros'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop<FiltrosProjeto>(context, (
            tipo: _tipo,
            status: _status,
            cliente: _cliente.text.trim(),
          )),
          style: ElevatedButton.styleFrom(
            backgroundColor: StyleProjetos.laranja,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Aplicar'),
        ),
      ],
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
