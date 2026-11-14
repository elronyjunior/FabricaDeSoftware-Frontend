import 'package:flutter/material.dart';

/// Desenha o [child] como se a tela tivesse [larguraBase] de largura
/// (a largura do Figma) e amplia/reduz tudo na mesma proporção.
///
/// Assim, em um monitor de 1920px, cards, botões, fontes e espaçamentos
/// ficam 1,5x maiores, mantendo exatamente as proporções da referência.
class EscalaDesign extends StatelessWidget {
  const EscalaDesign({
    super.key,
    required this.child,
    this.larguraBase = 1280,
    this.escalaMinima = 0.75,
    this.escalaMaxima = 2.0,
  });

  final Widget child;
  final double larguraBase;
  final double escalaMinima;
  final double escalaMaxima;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final escala = (constraints.maxWidth / larguraBase)
            .clamp(escalaMinima, escalaMaxima)
            .toDouble();

        return FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: constraints.maxWidth / escala,
            height: constraints.maxHeight / escala,
            child: child,
          ),
        );
      },
    );
  }
}
