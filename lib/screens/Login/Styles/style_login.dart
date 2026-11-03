import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens visuais da tela de login (medidas extraídas da referência 1280x832).
class StyleLogin {
  StyleLogin._();

  // ---------------- Cores ----------------
  static const Color fundo = Color(0xFF07072E);
  static const Color laranja = Color(0xFFFF5F00);
  static const Color laranjaClaro = Color(0xFFFF8A1F);
  /// Linha dos campos (contorno e separador do ícone): branco suave, como
  /// na referência (antes era azulada).
  static const Color bordaCampo = Color(0x8CFFFFFF);

  /// Preenchimento dos campos: um tom só, sem escurecer no hover ou no foco.
  static const Color fundoCampo = Color(0x1FFFFFFF);
  static const Color iconeCampo = Color(0xFF8D8DA3);
  static const Color linhaDivisor = Color(0xFF8E9BEF);
  static const Color texto = Colors.white;
  static const Color textoSecundario = Color(0xFFE4E4F0);

  // ---------------- Medidas ----------------
  /// Card quase quadrado (como o de Recuperar senha), igual nas três telas.
  static const double cardLargura = 560;

  /// Altura fixa do card (cabe o cadastro, a tela com mais campos).
  static const double cardAltura = 600;
  static const double cardRaio = 44;
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(48, 28, 48, 28);

  static const double campoLargura = 410;
  static const double campoAltura = 55;
  static const double raio = 10;

  static const Size botaoEntrarTamanho = Size(147, 40);
  static const Size botaoGoogleTamanho = Size(225, 40);

  // ---------------- Gradientes ----------------
  static const LinearGradient gradienteBotao = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [laranja, laranjaClaro],
  );

  static LinearGradient get gradienteCard => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.12),
          Colors.white.withOpacity(0.03),
        ],
      );

  // ---------------- Tipografia (Inter) ----------------
  static TextStyle get titulo => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w300,
        color: texto,
        letterSpacing: 0.2,
      );

  static TextStyle get campo => GoogleFonts.inter(fontSize: 16, color: texto);

  static TextStyle get hint =>
      GoogleFonts.inter(fontSize: 16, color: texto.withOpacity(0.92));

  static TextStyle get link => GoogleFonts.inter(
        fontSize: 12,
        color: textoSecundario,
        decoration: TextDecoration.underline,
        decorationColor: textoSecundario,
      );

  static TextStyle get rodape =>
      GoogleFonts.inter(fontSize: 12, color: textoSecundario);

  static TextStyle get divisor =>
      GoogleFonts.inter(fontSize: 12, color: textoSecundario);

  static TextStyle get botao => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle get botaoGoogle => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      );

  // ---------------- Botões ----------------
  /// O gradiente laranja é aplicado por um DecoratedBox em volta do botão.
  static ButtonStyle get btnEntrar => ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        fixedSize: botaoEntrarTamanho,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(raio)),
      );

  static ButtonStyle get btnGoogle => ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        disabledBackgroundColor: Colors.white70,
        foregroundColor: Colors.black,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        fixedSize: botaoGoogleTamanho,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(raio)),
      );

  // ---------------- Campos ----------------
  static OutlineInputBorder bordaInput({double largura = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(raio),
        borderSide: BorderSide(color: bordaCampo, width: largura),
      );
}