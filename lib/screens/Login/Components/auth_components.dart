import 'dart:ui';

import 'package:fabrica_software_app/screens/Login/Styles/style_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

// =====================================================================
// Componentes visuais compartilhados entre Login e Cadastro.
// Alterar algo aqui muda as duas telas ao mesmo tempo.
// =====================================================================

/// Estrutura completa da tela: fundo de partículas, card de vidro
/// centralizado e ícones de tema/ajuda no canto inferior direito.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.onAlternarTema,
    this.onAjuda,
  });

  final Widget child;
  final VoidCallback? onAlternarTema;
  final VoidCallback? onAjuda;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleLogin.fundo,
      body: Stack(
        children: [
          const Positioned.fill(child: _FundoAuth()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _CardVidro(child: child),
              ),
            ),
          ),
          Positioned(
            right: 56,
            bottom: 56,
            child: Row(
              children: [
                _IconeAcao(
                  icone: Icons.dark_mode,
                  dica: 'Alternar tema',
                  onTap: onAlternarTema ?? () {},
                ),
                const SizedBox(width: 20),
                _IconeAcao(
                  icone: Icons.help,
                  dica: 'Ajuda',
                  onTap: onAjuda ?? () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ícone laranja da Tegra + texto "tegra" em branco.
class LogoTegra extends StatelessWidget {
  const LogoTegra({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/image/tegra_logo_icon.png',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Text(
          'tegra',
          style: StyleLogin.titulo.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// Campo translúcido com ícone à esquerda separado por uma linha vertical.
class CampoVidro extends StatelessWidget {
  const CampoVidro({
    super.key,
    required this.controller,
    required this.hint,
    required this.icone,
    this.oculto = false,
    this.teclado,
    this.acao,
    this.aoEnviar,
    this.autofill,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icone;
  final bool oculto;
  final TextInputType? teclado;
  final TextInputAction? acao;
  final ValueChanged<String>? aoEnviar;
  final Iterable<String>? autofill;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: StyleLogin.campoLargura),
      child: SizedBox(
        height: StyleLogin.campoAltura,
        child: TextField(
          controller: controller,
          obscureText: oculto,
          keyboardType: teclado,
          textInputAction: acao,
          onSubmitted: aoEnviar,
          autofillHints: autofill,
          style: StyleLogin.campo,
          cursorColor: Colors.white,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: StyleLogin.hint,
            filled: true,
            fillColor: Colors.white.withOpacity(0.10),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 17),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 10, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, size: 26, color: StyleLogin.iconeCampo),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 40,
                    color: StyleLogin.bordaCampo,
                  ),
                ],
              ),
            ),
            border: StyleLogin.bordaInput(),
            enabledBorder: StyleLogin.bordaInput(),
            focusedBorder: StyleLogin.bordaInput(largura: 1.6),
          ),
        ),
      ),
    );
  }
}

/// Botão principal com gradiente laranja, 147x40, centralizado.
class BotaoLaranja extends StatelessWidget {
  const BotaoLaranja({
    super.key,
    required this.texto,
    required this.carregando,
    required this.onPressed,
  });

  final String texto;
  final bool carregando;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: StyleLogin.gradienteBotao,
        borderRadius: BorderRadius.circular(StyleLogin.raio),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: StyleLogin.btnEntrar,
        child: carregando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(texto, style: StyleLogin.botao),
      ),
    );
  }
}

/// Botão branco "Entrar com o google".
class BotaoGoogle extends StatelessWidget {
  const BotaoGoogle({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: StyleLogin.btnGoogle,
      icon: SvgPicture.asset('assets/SVG/Google_logo.svg', width: 22),
      label: Text('Entrar com o google', style: StyleLogin.botaoGoogle),
    );
  }
}

/// Linha – "Ou" – linha.
class DivisorOu extends StatelessWidget {
  const DivisorOu({super.key});

  @override
  Widget build(BuildContext context) {
    const linha = Expanded(
      child: Divider(thickness: 1, height: 1, color: StyleLogin.linhaDivisor),
    );
    return Row(
      children: [
        linha,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('Ou', style: StyleLogin.divisor),
        ),
        linha,
      ],
    );
  }
}

/// Texto sublinhado clicável.
class LinkSublinhado extends StatelessWidget {
  const LinkSublinhado({super.key, required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(texto, style: StyleLogin.link),
      ),
    );
  }
}

// ---------------- Privados ----------------

class _FundoAuth extends StatelessWidget {
  const _FundoAuth();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/image/login_background.png',
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
      errorBuilder: (_, __, ___) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.8, 0.3),
            radius: 1.3,
            colors: [Color(0xFF7A1E3A), Color(0xFF2A1450), StyleLogin.fundo],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

class _CardVidro extends StatelessWidget {
  const _CardVidro({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(StyleLogin.cardRaio);
    return ClipRRect(
      borderRadius: raio,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: StyleLogin.cardLargura),
          padding: StyleLogin.cardPadding,
          decoration: BoxDecoration(
            borderRadius: raio,
            gradient: StyleLogin.gradienteCard,
            border: Border.all(
              color: Colors.white.withOpacity(0.75),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _IconeAcao extends StatelessWidget {
  const _IconeAcao({
    required this.icone,
    required this.dica,
    required this.onTap,
  });

  final IconData icone;
  final String dica;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: dica,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Icon(icone, size: 28, color: Colors.white),
      ),
    );
  }
}