// Helpers visuais dos campos do formulário de projeto (criação e edição),
// no tema da IDV: fundo claro, borda fina, sem sombra e fonte Inter.
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ComponentsConfiguracaoInicalProjeto {
  static const Color fundoCampo = Color(0xFFF4F5FA);
  static const Color bordaCampo = Color(0x240F1030);

  // Label com asterisco vermelho nos campos obrigatórios
  static Widget buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: GoogleFonts.inter(
            color: StyleProjetos.texto,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: StyleProjetos.laranja),
              ),
          ],
        ),
      ),
    );
  }

  // Decoração do texto dentro da caixa (a caixa vem de inputBoxDecoration)
  static InputDecoration inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.inter(color: StyleProjetos.textoSecundario, fontSize: 14),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: icon != null
          ? Icon(icon, color: StyleProjetos.textoSecundario, size: 20)
          : null,
    );
  }

  static BoxDecoration inputBoxDecoration = BoxDecoration(
    color: fundoCampo,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: bordaCampo),
  );
}
