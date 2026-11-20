import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Relatorio/dados_relatorio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// =====================================================================
// Peças da tela de Relatórios no visual da IDV: cartões claros de cantos
// arredondados, azul-escuro e laranja, fonte Inter.
// =====================================================================

final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final moedaCurta =
    NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 1);
final dataCurta = DateFormat('dd/MM/yyyy');

/// Valor curto ("R\$ 1,6 mi"); abaixo de mil, o valor inteiro ("R\$ 0,00").
String dinheiroCurto(num v) => v.abs() < 1000 ? moeda.format(v) : moedaCurta.format(v);

const azulClaro = Color(0xFFA9B4F0);
const trilho = Color(0xFFE4E6F0);

Color corDoStatus(String status) => switch (status) {
      'Concluído' => StyleProjetos.azulEscuro,
      'Atrasado' => const Color(0xFFD62A1E),
      _ => const Color(0xFF2EBD5F),
    };

TextStyle _texto(double tamanho,
        {FontWeight peso = FontWeight.w400, Color cor = StyleProjetos.texto}) =>
    GoogleFonts.inter(fontSize: tamanho, fontWeight: peso, color: cor);

/// Cartão base dos relatórios: título, subtítulo e uma ação à direita.
class CartaoRelatorio extends StatelessWidget {
  const CartaoRelatorio({
    super.key,
    required this.titulo,
    required this.child,
    this.subtitulo,
    this.acao,
    this.altura,
  });

  final String titulo;
  final String? subtitulo;
  final Widget? acao;
  final Widget child;
  final double? altura;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: altura,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: StyleProjetos.painel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: _texto(16, peso: FontWeight.w600)),
                    if (subtitulo != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitulo!,
                          style: _texto(12.5, cor: StyleProjetos.textoSecundario)),
                    ],
                  ],
                ),
              ),
              if (acao != null) acao!,
            ],
          ),
          const SizedBox(height: 18),
          if (altura != null) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

/// Indicador grande (KPI). [destaque] usa o fundo azul-escuro.
class IndicadorRelatorio extends StatelessWidget {
  const IndicadorRelatorio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.valor,
    this.complemento,
    this.detalhe,
    this.destaque = false,
  });

  final IconData icone;
  final String titulo;
  final String valor;

  /// Pequeno depois do valor ("/22", "%").
  final String? complemento;
  final String? detalhe;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final corTexto = destaque ? Colors.white : StyleProjetos.texto;
    final corSecundaria =
        destaque ? Colors.white.withOpacity(0.7) : StyleProjetos.textoSecundario;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: destaque
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [StyleProjetos.azulEscuro, Color(0xFF2A2C5C)],
              ),
              boxShadow: [
                BoxShadow(
                  // Leve: mais forte, marcava uma faixa escura atrás da linha.
                  color: StyleProjetos.azulEscuro.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : StyleProjetos.painel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: destaque ? StyleProjetos.gradienteLaranja : null,
                  color: destaque ? null : StyleProjetos.azulEscuro,
                ),
                child: Icon(icone, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _texto(13.5, peso: FontWeight.w600, cor: corTexto)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: valor,
                  style: _texto(28, peso: FontWeight.w700, cor: corTexto)
                      .copyWith(letterSpacing: -0.5)),
              if (complemento != null)
                TextSpan(
                    text: complemento,
                    style: _texto(16, peso: FontWeight.w500, cor: corSecundaria)),
            ])),
          ),
          if (detalhe != null) ...[
            const SizedBox(height: 4),
            Text(detalhe!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _texto(12, cor: corSecundaria)),
          ],
        ],
      ),
    );
  }
}

/// Gráfico de colunas: a maior coluna em laranja, as outras em azul claro,
/// com o valor dela num balão em cima (como no exemplo de painel).
class GraficoColunas extends StatelessWidget {
  const GraficoColunas({super.key, required this.itens, this.formatar});

  final List<ItemGrafico> itens;
  final String Function(double valor)? formatar;

  String _fmt(double v) => formatar?.call(v) ?? v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty || itens.every((i) => i.valor == 0)) {
      return const SemDados();
    }
    final maior = itens.map((i) => i.valor).reduce((a, b) => a > b ? a : b);
    // Entre colunas empatadas, destaca a mais recente.
    final indiceMaior = itens.lastIndexWhere((i) => i.valor == maior);
    // Teto múltiplo de 4: as 4 linhas da grade caem em números redondos.
    final passo = maior <= 4 ? 1.0 : (maior * 1.2 / 4).ceilToDouble();
    final teto = passo * 4;
    final largura = (220 / itens.length).clamp(10.0, 34.0);

    return BarChart(
      BarChartData(
        maxY: teto,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: passo,
          getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0x1A0F1030), strokeWidth: 1, dashArray: [4, 4]),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: formatar == null ? 26 : 54,
              interval: passo,
              getTitlesWidget: (v, meta) => Text(
                v == meta.max ? '' : _fmt(v),
                style: _texto(10.5, cor: StyleProjetos.textoSecundario),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= itens.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(itens[i].rotulo,
                      style: _texto(11,
                          peso: i == indiceMaior ? FontWeight.w600 : FontWeight.w400,
                          cor: i == indiceMaior
                              ? StyleProjetos.texto
                              : StyleProjetos.textoSecundario)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => StyleProjetos.azulEscuro,
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${itens[group.x].detalhe ?? itens[group.x].rotulo}\n',
              _texto(11, cor: Colors.white70),
              children: [
                TextSpan(
                    text: _fmt(rod.toY),
                    style: _texto(13, peso: FontWeight.w700, cor: Colors.white)),
              ],
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < itens.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: itens[i].valor,
                  width: largura,
                  borderRadius: BorderRadius.circular(largura / 2),
                  gradient: i == indiceMaior
                      ? const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [StyleProjetos.laranja, StyleProjetos.laranjaClaro])
                      : null,
                  color: i == indiceMaior ? null : azulClaro,
                  backDrawRodData: BackgroundBarChartRodData(
                      show: true, toY: teto, color: trilho.withOpacity(0.55)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Fatia de um gráfico de rosca.
class Fatia {
  const Fatia(this.rotulo, this.valor, this.cor);
  final String rotulo;
  final double valor;
  final Color cor;
}

/// Rosca com o total no meio e a legenda ao lado.
class GraficoRosca extends StatelessWidget {
  const GraficoRosca({
    super.key,
    required this.fatias,
    required this.rotuloCentro,
    this.valorCentro,
  });

  final List<Fatia> fatias;
  final String rotuloCentro;
  final String? valorCentro;

  @override
  Widget build(BuildContext context) {
    final total = fatias.fold<double>(0, (s, f) => s + f.valor);
    if (total == 0) return const SemDados();

    final rosca = SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 50,
            startDegreeOffset: -90,
            sections: [
              for (final f in fatias)
                if (f.valor > 0)
                  PieChartSectionData(
                      value: f.valor, color: f.cor, radius: 20, showTitle: false),
            ],
          )),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(valorCentro ?? total.toStringAsFixed(0),
                  style: _texto(24, peso: FontWeight.w700)),
              Text(rotuloCentro,
                  style: _texto(11, cor: StyleProjetos.textoSecundario)),
            ],
          ),
        ],
      ),
    );

    final legenda = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in fatias)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: f.cor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(f.rotulo, style: _texto(13)),
                const SizedBox(width: 10),
                Text(
                  '${f.valor.toStringAsFixed(0)} · ${(f.valor / total * 100).round()}%',
                  style: _texto(12.5,
                      peso: FontWeight.w600, cor: StyleProjetos.textoSecundario),
                ),
              ],
            ),
          ),
      ],
    );

    // Wrap (e não LayoutBuilder): os cartões medem a altura dos vizinhos
    // (IntrinsicHeight), e LayoutBuilder não informa altura assim.
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 28,
        runSpacing: 16,
        children: [rosca, legenda],
      ),
    );
  }
}

/// Lista com barras horizontais (ranking).
class BarrasHorizontais extends StatelessWidget {
  const BarrasHorizontais({super.key, required this.itens, required this.formatar});

  final List<ItemGrafico> itens;
  final String Function(double) formatar;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return const SemDados();
    final maior = itens.first.valor <= 0 ? 1.0 : itens.first.valor;
    return Column(
      children: [
        for (var i = 0; i < itens.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(itens[i].rotulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _texto(13, peso: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    Text(formatar(itens[i].valor),
                        style: _texto(13, peso: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (itens[i].valor / maior).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: trilho,
                    valueColor: AlwaysStoppedAnimation(
                        i == 0 ? StyleProjetos.laranja : StyleProjetos.azulEscuro),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Etiqueta de status do projeto (mesmo degradê dos cards de projeto).
class EtiquetaStatusRelatorio extends StatelessWidget {
  const EtiquetaStatusRelatorio(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final estilo = EstiloStatus.de(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: estilo.gradiente,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status,
          style: StyleProjetos.pill.copyWith(color: estilo.corTexto)),
    );
  }
}

/// Tabela simples (cabeçalho + linhas) no padrão das telas de gestão.
class TabelaRelatorio extends StatelessWidget {
  const TabelaRelatorio({
    super.key,
    required this.colunas,
    required this.linhas,
    this.pesos,
    this.vazio = 'Nenhum projeto no filtro atual.',
  });

  final List<String> colunas;
  final List<List<Widget>> linhas;
  final List<int>? pesos;
  final String vazio;

  @override
  Widget build(BuildContext context) {
    if (linhas.isEmpty) return SemDados(texto: vazio);
    int peso(int i) => pesos != null && i < pesos!.length ? pesos![i] : 1;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(children: [
            for (var i = 0; i < colunas.length; i++)
              Expanded(
                flex: peso(i),
                child: Text(colunas[i],
                    style: _texto(12,
                        peso: FontWeight.w600, cor: StyleProjetos.textoSecundario)),
              ),
          ]),
        ),
        const Divider(height: 1, color: Color(0x1F0F1030)),
        for (final linha in linhas)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x140F1030)))),
            child: Row(children: [
              for (var i = 0; i < linha.length; i++)
                Expanded(
                  flex: peso(i),
                  child: Align(alignment: Alignment.centerLeft, child: linha[i]),
                ),
            ]),
          ),
      ],
    );
  }
}

/// Texto de uma célula da tabela (com segunda linha opcional).
class CelulaRelatorio extends StatelessWidget {
  const CelulaRelatorio(this.texto, {super.key, this.abaixo, this.forte = false});
  final String texto;
  final String? abaixo;
  final bool forte;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _texto(13, peso: forte ? FontWeight.w600 : FontWeight.w400)),
        if (abaixo != null)
          Text(abaixo!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _texto(11.5, cor: StyleProjetos.textoSecundario)),
      ],
    );
  }
}

class SemDados extends StatelessWidget {
  const SemDados({super.key, this.texto = 'Sem dados no filtro atual.'});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_outlined,
                color: StyleProjetos.textoSecundario, size: 26),
            const SizedBox(height: 8),
            Text(texto, style: _texto(13, cor: StyleProjetos.textoSecundario)),
          ],
        ),
      ),
    );
  }
}
