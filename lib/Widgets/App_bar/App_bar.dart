import 'package:flutter/material.dart';

// ignore: must_be_immutable
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  late List<Widget>? listaActions = [];

  CustomAppBar({super.key, required this.title, this.listaActions});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      // Transparente: o fundo é o degradê do LayoutPrincipal.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      iconTheme: IconThemeData(
        size: 40,
        weight: 700.0,
      ),
      actions: listaActions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
