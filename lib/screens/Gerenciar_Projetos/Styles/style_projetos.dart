import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens visuais da tela "Gestão de Projetos" (medidas da referência 1280x832).
class StyleProjetos {
  StyleProjetos._();

  // ---------------- Cores ----------------
  static const Color fundoInicio = Color(0xFFE1E4EE);
  static const Color fundoFim = Color(0xFFF3F4FA);
  static const Color azulEscuro = Color(0xFF0F1030);
  static const Color texto = Color(0xFF14142B);
  static const Color textoSecundario = Color(0xFF6E7183);
  static const Color laranja = Color(0xFFFF5F00);
  static const Color laranjaClaro = Color(0xFFFF8A1F);

  static const LinearGradient gradienteFundo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [fundoInicio, fundoFim],
  );

  static const LinearGradient gradienteLaranja = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [laranja, laranjaClaro],
  );

  /// Superfície clara translúcida usada no menu lateral e nos cards.
  static BoxDecoration superficie({double raio = cardRaio}) => BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(raio),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C1F3A).withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // ---------------- Medidas ----------------
  static const double sidebarLargura = 70; // menu fechado (mais fino)
  static const double sidebarRaio = 35;
  static const double sidebarAbertaLargura = 400;
  static const double sidebarAbertaRaio = 28;

  /// Tom do vidro fumê do menu aberto (a opacidade é aplicada no menu).
  static const Color vidroEscuro = Color(0xFF2B2B36);
  static const double cardAltura = 214;
  static const double cardRaio = 14;
  static const double controleAltura = 30; // filtro e pesquisa
  static const double botaoRaio = 14; // Novo Projeto
  static const double ferramentaIcone = 22; // ordenar e recarregar

  // ---------------- Tipografia (Inter) ----------------
  static TextStyle get titulo => GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: texto,
        letterSpacing: -0.3,
      );

  static TextStyle get subtitulo => GoogleFonts.inter(
      fontSize: 17, fontWeight: FontWeight.w600, color: texto);

  static TextStyle get botao => GoogleFonts.inter(
      fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white);

  static TextStyle get controle =>
      GoogleFonts.inter(fontSize: 15, color: texto);

  static TextStyle get contador =>
      GoogleFonts.inter(fontSize: 14, color: texto);

  static TextStyle get pesquisa =>
      GoogleFonts.inter(fontSize: 14, color: texto);

  static TextStyle get cardTitulo => GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w600, color: texto);

  static TextStyle get cardCliente =>
      GoogleFonts.inter(fontSize: 14, color: textoSecundario);

  static TextStyle get cardDescricao =>
      GoogleFonts.inter(fontSize: 13, color: textoSecundario, height: 1.3);

  static TextStyle get cardRodape =>
      GoogleFonts.inter(fontSize: 13, color: textoSecundario);

  static TextStyle get pill =>
      GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600);

  static TextStyle get paginacao =>
      GoogleFonts.inter(fontSize: 18, color: texto);
}

/// Cor e gradiente da etiqueta de status de cada projeto.
class EstiloStatus {
  const EstiloStatus({required this.gradiente, required this.corTexto});

  final Gradient gradiente;
  final Color corTexto;

  static EstiloStatus de(String status) {
    switch (status) {
      case 'Concluído':
        return const EstiloStatus(
          gradiente: LinearGradient(
              colors: [Color(0xFFA9C3F5), StyleProjetos.azulEscuro]),
          corTexto: Colors.white,
        );
      case 'Atrasado':
      case 'Cancelado':
        return const EstiloStatus(
          gradiente:
              LinearGradient(colors: [Color(0xFFD62A1E), Color(0xFFF4A09A)]),
          corTexto: Colors.white,
        );
      case 'Pausado':
        return const EstiloStatus(
          gradiente:
              LinearGradient(colors: [Color(0xFFFFF7A1), Color(0xFFFFE600)]),
          corTexto: StyleProjetos.azulEscuro,
        );
      default: // Em processo
        return const EstiloStatus(
          gradiente:
              LinearGradient(colors: [Color(0xFFA6EBB8), Color(0xFF2EBD5F)]),
          corTexto: StyleProjetos.azulEscuro,
        );
    }
  }
}
