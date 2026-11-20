import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Relatorio/dados_relatorio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Abre o painel de filtros; devolve os filtros escolhidos (null = cancelou).
Future<FiltrosRelatorio?> abrirFiltrosRelatorio(
  BuildContext context, {
  required FiltrosRelatorio atuais,
  required List<String> clientes,
  required List<String> tipos,
}) {
  return mostrarDialogo<FiltrosRelatorio>(
    context: context,
    builder: (_) =>
        _PainelFiltros(atuais: atuais, clientes: clientes, tipos: tipos),
  );
}

class _PainelFiltros extends StatefulWidget {
  const _PainelFiltros(
      {required this.atuais, required this.clientes, required this.tipos});

  final FiltrosRelatorio atuais;
  final List<String> clientes;
  final List<String> tipos;

  @override
  State<_PainelFiltros> createState() => _PainelFiltrosState();
}

class _PainelFiltrosState extends State<_PainelFiltros> {
  late FiltrosRelatorio _f = widget.atuais;

  Set<String> _alternar(Set<String> atual, String valor) {
    final novo = {...atual};
    novo.contains(valor) ? novo.remove(valor) : novo.add(valor);
    return novo;
  }

  void _limpar() => setState(() => _f = FiltrosRelatorio(
      periodo: widget.atuais.periodo == PeriodoRapido.personalizado
          ? PeriodoRapido.tudo
          : widget.atuais.periodo));

  @override
  Widget build(BuildContext context) {
    final personalizado = _f.periodo == PeriodoRapido.personalizado;
    return PainelIdv(
      titulo: 'Filtros',
      ajuda: 'Os filtros valem para todos os números, gráficos e para o PDF '
          'exportado.',
      largura: 520,
      rotuloAcao: 'Aplicar filtros',
      aoConfirmar: () => Navigator.pop(context, _f),
      acoesExtras: [
        TextButton(
          onPressed: _f.ativos == 0 ? null : _limpar,
          child: Text('Limpar filtros',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _f.ativos == 0
                      ? StyleProjetos.textoSecundario
                      : StyleProjetos.laranja)),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SecaoIdv('Período',
              descricao: 'Pela data de início de cada projeto.'),
          _Chips(
            opcoes: [for (final p in PeriodoRapido.values) p.rotulo],
            selecionados: {_f.periodo.rotulo},
            aoTocar: (r) => setState(() => _f = _f.copiar(
                periodo:
                    PeriodoRapido.values.firstWhere((p) => p.rotulo == r))),
          ),
          if (personalizado) ...[
            const SizedBox(height: 14),
            PeriodoIdv(
              inicio: _f.inicio,
              fim: _f.fim,
              aoMudar: (i, f) => setState(() => _f = FiltrosRelatorio(
                    periodo: PeriodoRapido.personalizado,
                    inicio: i,
                    fim: f,
                    status: _f.status,
                    clientes: _f.clientes,
                    complexidades: _f.complexidades,
                    tipos: _f.tipos,
                  )),
            ),
          ],
          const SizedBox(height: 24),
          const SecaoIdv('Status'),
          _Chips(
            opcoes: statusProjeto,
            selecionados: _f.status,
            aoTocar: (v) =>
                setState(() => _f = _f.copiar(status: _alternar(_f.status, v))),
          ),
          const SizedBox(height: 24),
          const SecaoIdv('Complexidade'),
          _Chips(
            opcoes: const ['Baixa', 'Média', 'Alta'],
            selecionados: _f.complexidades,
            aoTocar: (v) => setState(() => _f =
                _f.copiar(complexidades: _alternar(_f.complexidades, v))),
          ),
          // Clientes e tipos podem ser muitos: busca com seleção múltipla
          // (o mesmo campo das tecnologias no Novo projeto).
          if (widget.clientes.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SecaoIdv('Clientes'),
            BuscaSelecaoIdv(
              itens: widget.clientes,
              rotulo: (c) => c as String,
              hintBusca: 'Pesquisar cliente',
              textoVazio: 'Nenhum cliente nos projetos.',
              textoNenhumSelecionado: 'Todos os clientes.',
              marcado: (c) => _f.clientes.contains(c),
              aoAlternar: (c) => setState(() =>
                  _f = _f.copiar(clientes: _alternar(_f.clientes, c as String))),
            ),
          ],
          if (widget.tipos.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SecaoIdv('Tipo de projeto'),
            BuscaSelecaoIdv(
              itens: widget.tipos,
              rotulo: (t) => t as String,
              hintBusca: 'Pesquisar tipo',
              textoVazio: 'Nenhum tipo nos projetos.',
              textoNenhumSelecionado: 'Todos os tipos.',
              marcado: (t) => _f.tipos.contains(t),
              aoAlternar: (t) => setState(
                  () => _f = _f.copiar(tipos: _alternar(_f.tipos, t as String))),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opções em pílulas: selecionada em azul-escuro, as outras com contorno.
class _Chips extends StatelessWidget {
  const _Chips(
      {required this.opcoes, required this.selecionados, required this.aoTocar});

  final List<String> opcoes;
  final Set<String> selecionados;
  final ValueChanged<String> aoTocar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in opcoes)
          _Chip(
            rotulo: o,
            selecionado: selecionados.contains(o),
            aoTocar: () => aoTocar(o),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.rotulo, required this.selecionado, required this.aoTocar});

  final String rotulo;
  final bool selecionado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: aoTocar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selecionado ? StyleProjetos.azulEscuro : CoresIdv.campo,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selecionado ? StyleProjetos.azulEscuro : CoresIdv.borda),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selecionado) ...[
                const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 5),
              ],
              Text(rotulo,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: selecionado ? FontWeight.w600 : FontWeight.w500,
                      color: selecionado ? Colors.white : StyleProjetos.texto)),
            ],
          ),
        ),
      ),
    );
  }
}
