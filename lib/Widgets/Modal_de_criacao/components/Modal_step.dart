import 'package:flutter/material.dart';

abstract class ModalStep {
  String get title;
  IconData get icon;
  String get tabName;
  List<Color> get cores;

  // true = o passo cuida da própria rolagem (ex: layout de duas colunas com
  // um painel de chat que precisa de altura limitada). Default false
  // preserva o comportamento de todos os passos existentes (ModalDeCriacao
  // envolve o corpo num SingleChildScrollView).
  bool get temPainelProprio => false;

  Widget buildBody(BuildContext context);
  Widget buildFooter(BuildContext context);
}