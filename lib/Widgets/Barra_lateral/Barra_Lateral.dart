import 'dart:math' as math;

import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:flutter/material.dart';

/// Drawer com o menu lateral do app, usado em telas estreitas.
/// Em telas largas o menu já fica fixo pelo [LayoutPrincipal].
class BarraLateral extends StatelessWidget {
  const BarraLateral({super.key});

  /// Use em `Scaffold(drawer: BarraLateral.drawer(context))`:
  /// devolve `null` quando o menu já está fixo na tela.
  static Widget? drawer(BuildContext context) =>
      LayoutPrincipal.menuFixo(context) ? null : const BarraLateral();

  @override
  Widget build(BuildContext context) {
    final largura = math.min(MediaQuery.sizeOf(context).width * 0.9, 424.0);

    return Drawer(
      width: largura,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Builder(
            builder: (context) => MenuLateral(
              sempreAberta: true,
              aoNavegar: () => Scaffold.maybeOf(context)?.closeDrawer(),
            ),
          ),
        ),
      ),
    );
  }
}
