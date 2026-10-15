import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens visuais do formulário conversacional (medidas da referência:
/// modal de 1000x600).
class EstiloConversa {
  EstiloConversa._();

  // ---------------- Medidas ----------------
  static const double largura = 1000;
  static const double altura = 600;
  static const double raio = 30;
  static const double larguraEtapas = 231;
  static const double alturaBarra = 42;

  // ---------------- Cores ----------------
  static const Color azulEscuro = Color(0xFF0F1030);
  static const Color texto = Color(0xFF14142B);
  static const Color textoSecundario = Color(0xFF6E7183);
  static const Color laranja = Color(0xFFFF6A00);
  static const Color laranjaEtapa = Color(0xFFFF7A1A);
  static const Color verde = Color(0xFF6BAA70);
  static const Color balaoSistema = Color(0xFFEBEDF4);
  static const Color fundoBarra = Color(0xFFE3E6EF);
  static const Color trilhaProgresso = Color(0xFFF2F3F7);
  static const Color divisoria = Color(0xFF9DA6C9);
  static const Color contornoEtapas = Color(0xFFA9B4DE);
  static const Color desabilitado = Color(0xFFA3A6B4);

  /// Barreira escura por trás do modal (também cobre o menu lateral).
  static const Color barreira = Color(0xB8000000);
  static const double desfoqueBarreira = 8;

  static const LinearGradient fundoEtapas = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD3D8E6), Color(0xFFDDE1EB), Color(0xFFF5F6F9)],
    stops: [0, 0.55, 1],
  );

  static const LinearGradient fundoConversa = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE4E7F1), Color(0xFFD3D8E5), Color(0xFFCDD3E2)],
    stops: [0, 0.5, 1],
  );

  static const LinearGradient gradienteLaranja = LinearGradient(
    colors: [Color(0xFFFF6200), Color(0xFFFF7A1F)],
  );

  // ---------------- Tipografia ----------------
  static TextStyle fonte({
    double tamanho = 16,
    FontWeight peso = FontWeight.w400,
    Color cor = texto,
    double? altura,
  }) =>
      GoogleFonts.roboto(
        fontSize: tamanho,
        fontWeight: peso,
        color: cor,
        height: altura,
      );
}
