import 'dart:typed_data';

import 'package:fabrica_software_app/screens/Relatorio/components/pecas_relatorio.dart';
import 'package:fabrica_software_app/screens/Relatorio/dados_relatorio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// PDF do relatório com o que está na tela (mesmos filtros e pesquisa).

const _azul = PdfColor.fromInt(0xFF0F1030);
const _laranja = PdfColor.fromInt(0xFFFF5F00);
const _cinza = PdfColor.fromInt(0xFF6E7183);
const _linha = PdfColor.fromInt(0xFFE4E6F0);

String _resumoFiltros(DadosRelatorioProvider d) {
  final f = d.filtros;
  final partes = <String>[];
  if (f.periodo == PeriodoRapido.personalizado) {
    final (i, fim) = f.intervalo;
    partes.add('Período: ${i == null ? '...' : dataCurta.format(i)} a '
        '${fim == null ? '...' : dataCurta.format(fim)}');
  } else {
    partes.add('Período: ${f.periodo.rotulo}');
  }
  if (f.status.isNotEmpty) partes.add('Status: ${f.status.join(', ')}');
  if (f.complexidades.isNotEmpty) {
    partes.add('Complexidade: ${f.complexidades.join(', ')}');
  }
  if (f.clientes.isNotEmpty) partes.add('Clientes: ${f.clientes.join(', ')}');
  if (f.tipos.isNotEmpty) partes.add('Tipo: ${f.tipos.join(', ')}');
  if (d.busca.trim().isNotEmpty) partes.add('Pesquisa: "${d.busca.trim()}"');
  // '·' existe na fonte padrão do PDF ('•' vira um quadrado).
  return partes.join('   ·   ');
}

pw.Widget _indicador(String titulo, String valor) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _linha),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(titulo, style: const pw.TextStyle(fontSize: 8, color: _cinza)),
            pw.SizedBox(height: 4),
            pw.Text(valor,
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold, color: _azul)),
          ],
        ),
      ),
    );

pw.Widget _titulo(String texto) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
      child: pw.Text(texto,
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: _azul)),
    );

Future<Uint8List> construirPdfRelatorio(DadosRelatorioProvider d) async {
  final doc = pw.Document(title: 'Relatório de projetos');
  final projetos = d.projetos;
  final status = d.porStatus;
  final taxa = d.taxaTestes;

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    header: (_) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _laranja, width: 2))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Relatório de projetos',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold, color: _azul)),
          pw.Text('Gerado em ${dataCurta.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: _cinza)),
        ],
      ),
    ),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _cinza)),
    ),
    build: (_) => [
      pw.SizedBox(height: 8),
      pw.Text(_resumoFiltros(d),
          style: const pw.TextStyle(fontSize: 9, color: _cinza)),
      pw.SizedBox(height: 12),
      pw.Row(children: [
        _indicador('Projetos', '${projetos.length}'),
        _indicador('Orçamento estimado', moeda.format(d.orcamentoTotal)),
        _indicador('Custo de recursos', moeda.format(d.custoRecursos)),
        _indicador('Testes concluídos',
            taxa == null ? '—' : '${taxa.round()}%'),
      ]),
      _titulo('Projetos por status'),
      pw.Text(
          statusProjeto.map((s) => '$s: ${status[s] ?? 0}').join('     '),
          style: const pw.TextStyle(fontSize: 10)),
      _titulo('Projetos'),
      if (projetos.isEmpty)
        pw.Text('Nenhum projeto no filtro atual.',
            style: const pw.TextStyle(fontSize: 10, color: _cinza))
      else
        pw.TableHelper.fromTextArray(
          headers: ['Projeto', 'Cliente', 'Início', 'Status', 'Orçamento'],
          data: [
            for (final p in projetos)
              [
                p.nomeProjeto,
                p.clienteNome ?? '—',
                DadosRelatorioProvider.dataDo(p) == null
                    ? '—'
                    : dataCurta.format(DadosRelatorioProvider.dataDo(p)!),
                p.statusCalculado,
                p.orcamentoEstimado == null ? '—' : moeda.format(p.orcamentoEstimado),
              ],
          ],
          headerStyle: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _azul),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {4: pw.Alignment.centerRight},
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F6FA)),
          border: null,
        ),
      _titulo('Custo de recursos por projeto'),
      ...() {
        final itens = d.custoPorProjeto(limite: 10);
        if (itens.isEmpty) {
          return [
            pw.Text('Sem alocações de recursos no filtro atual.',
                style: const pw.TextStyle(fontSize: 10, color: _cinza))
          ];
        }
        return [
          for (final i in itens)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(i.rotulo, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(moeda.format(i.valor),
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
        ];
      }(),
      _titulo('Testes e treinamentos'),
      pw.Text(
        'Testes: ${d.testes.length} '
        '(${rotulosSituacaoTeste.entries.map((e) => '${e.value}: ${d.testesPorSituacao[e.key] ?? 0}').join(', ')})',
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        'Treinamentos: ${d.treinamentos.length} '
        '(${d.treinamentosConcluidos} '
        '${d.treinamentosConcluidos == 1 ? 'concluído' : 'concluídos'}, '
        '${d.horasTreinamento} h no total)',
        style: const pw.TextStyle(fontSize: 10),
      ),
    ],
  ));
  return doc.save();
}

Future<void> exportarRelatorioPdf(DadosRelatorioProvider dados) async {
  final bytes = await construirPdfRelatorio(dados);
  final hoje = DateTime.now();
  final nome = 'relatorio-projetos-${hoje.year}-'
      '${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}.pdf';
  await Printing.sharePdf(bytes: bytes, filename: nome);
}
