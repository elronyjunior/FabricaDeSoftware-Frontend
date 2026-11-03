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

  // Usados pelo painel de criação com abas (ModalNovoProjeto), onde o
  // usuário troca de aba livremente em vez de avançar passo a passo.

  /// Aba que precisa ser aberta e validada antes de criar o projeto.
  bool get obrigatoria => true;

  /// Explicação da aba, mostrada no ícone "?" ao lado do título.
  String? get ajuda => null;

  /// Valida os dados da aba (mostra o próprio aviso quando falha).
  bool validar() => true;

  /// Grava no ProjetoDTO o que só é salvo ao sair da aba.
  void salvar() {}

  Widget buildBody(BuildContext context);
  Widget buildFooter(BuildContext context);
}
