import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// =====================================================================
// Painel de criação/edição no mesmo formato do "Novo projeto": entra pela
// direita, cabeçalho com título e X, campos claros de borda fina e rodapé
// com Cancelar + botão laranja. Usado por todos os modais de criar,
// adicionar, editar e ver (Clientes, Recursos, Tecnologias...).
// =====================================================================

const _borda = Color(0x1F0F1030);

/// Tema da IDV para o conteúdo dos painéis: Inter, azul-escuro e nada com
/// sombra.
ThemeData temaIdv(ThemeData base) {
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    colorScheme: base.colorScheme.copyWith(
      primary: StyleProjetos.azulEscuro,
      surfaceTint: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: forma,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: forma,
        side: const BorderSide(color: Color(0x330F1030)),
      ),
    ),
    cardTheme:
        const CardThemeData(elevation: 0, shadowColor: Colors.transparent),
    chipTheme: base.chipTheme.copyWith(
      elevation: 0,
      pressElevation: 0,
      shadowColor: Colors.transparent,
      side: const BorderSide(color: Color(0x240F1030)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 0,
      hoverElevation: 0,
      focusElevation: 0,
      highlightElevation: 0,
    ),
  );
}

/// Painel lateral da IDV. Abra com `mostrarDialogo` (como qualquer modal):
/// ele mesmo se encaixa à direita e entra deslizando.
///
/// Sem [rotuloAcao] o rodapé mostra só "Fechar" (modo de visualização).
class PainelIdv extends StatelessWidget {
  const PainelIdv({
    super.key,
    required this.titulo,
    required this.child,
    this.ajuda,
    this.rotuloAcao,
    this.aoConfirmar,
    this.carregando = false,
    this.largura = 600,
    this.aoFechar,
    this.acoesExtras = const [],
  });

  final String titulo;

  /// Conteúdo do corpo (já rola sozinho).
  final Widget child;

  /// Texto do "?" ao lado do título.
  final String? ajuda;

  /// Texto do botão laranja ("Criar cliente", "Salvar alterações").
  final String? rotuloAcao;
  final VoidCallback? aoConfirmar;

  /// Salvando: botões travados e o laranja mostra o carregamento.
  final bool carregando;

  final double largura;

  /// Padrão: fecha o painel.
  final VoidCallback? aoFechar;

  /// Botões à esquerda do rodapé (ex.: "Editar endereço").
  final List<Widget> acoesExtras;

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.of(context).size;
    final larguraPainel =
        largura.clamp(0.0, tela.width - 32).toDouble();
    final fechar = aoFechar ?? () => Navigator.pop(context);

    final painel = SizedBox(
      width: larguraPainel,
      height: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StyleProjetos.sidebarAbertaRaio),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: temaIdv(Theme.of(context)),
          child: AvisosIdv(
            child: Column(
              children: [
                _CabecalhoPainel(
                  titulo: titulo,
                  ajuda: ajuda,
                  aoFechar: carregando ? null : fechar,
                ),
                const Divider(height: 1, color: _borda),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                    child: child,
                  ),
                ),
                const Divider(height: 1, color: _borda),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
                  child: Row(
                    children: [
                      ...acoesExtras,
                      const Spacer(),
                      BotaoSecundarioIdv(
                        rotulo: rotuloAcao == null ? 'Fechar' : 'Cancelar',
                        aoTocar: carregando ? null : fechar,
                      ),
                      if (rotuloAcao != null) ...[
                        const SizedBox(width: 12),
                        BotaoPrincipalIdv(
                          rotulo: rotuloAcao!,
                          aoTocar: aoConfirmar,
                          carregando: carregando,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Entra pela direita, como o painel do Novo projeto.
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, t, filho) => Transform.translate(
            offset: Offset(larguraPainel * 0.08 * (1 - t), 0),
            child: Opacity(opacity: t, child: filho),
          ),
          child: painel,
        ),
      ),
    );
  }
}

class _CabecalhoPainel extends StatelessWidget {
  const _CabecalhoPainel(
      {required this.titulo, required this.ajuda, required this.aoFechar});

  final String titulo;
  final String? ajuda;
  final VoidCallback? aoFechar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 16, 18),
      child: Row(
        children: [
          // Título e "?" ocupam o resto da linha: o X fica no canto direito.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: StyleProjetos.texto,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (ajuda != null) ...[
                  const SizedBox(width: 10),
                  AjudaIdv(texto: ajuda!),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fechar',
            onPressed: aoFechar,
            icon: const Icon(Icons.close, color: StyleProjetos.textoSecundario),
          ),
        ],
      ),
    );
  }
}

final _pilula = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(StyleProjetos.botaoRaio));
TextStyle get _textoBotao =>
    GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600);

/// Botão de contorno do rodapé (Cancelar, Fechar, ações extras).
class BotaoSecundarioIdv extends StatelessWidget {
  const BotaoSecundarioIdv(
      {super.key, required this.rotulo, required this.aoTocar, this.icone});

  final String rotulo;
  final VoidCallback? aoTocar;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final estilo = OutlinedButton.styleFrom(
      foregroundColor: StyleProjetos.texto,
      side: const BorderSide(color: Color(0x330F1030)),
      shape: _pilula,
      minimumSize: const Size(120, 46),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      textStyle: _textoBotao,
    );
    if (icone == null) {
      return OutlinedButton(
          onPressed: aoTocar, style: estilo, child: Text(rotulo));
    }
    return OutlinedButton.icon(
      onPressed: aoTocar,
      style: estilo,
      icon: Icon(icone, size: 18),
      label: Text(rotulo),
    );
  }
}

/// Botão laranja do rodapé. [perigo] deixa vermelho (excluir).
class BotaoPrincipalIdv extends StatelessWidget {
  const BotaoPrincipalIdv({
    super.key,
    required this.rotulo,
    required this.aoTocar,
    this.carregando = false,
    this.perigo = false,
  });

  final String rotulo;
  final VoidCallback? aoTocar;
  final bool carregando;
  final bool perigo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: perigo ? null : StyleProjetos.gradienteLaranja,
        color: perigo ? CoresIdv.vermelho : null,
        borderRadius: BorderRadius.circular(StyleProjetos.botaoRaio),
      ),
      child: ElevatedButton(
        onPressed: carregando ? null : aoTocar,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: _pilula,
          minimumSize: const Size(160, 46),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: _textoBotao,
        ),
        child: carregando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(rotulo),
      ),
    );
  }
}

/// Confirmação curta (excluir) no mesmo visual: cartão branco no centro,
/// ícone, título, texto e os dois botões.
class ConfirmacaoIdv extends StatelessWidget {
  const ConfirmacaoIdv({
    super.key,
    required this.titulo,
    required this.mensagem,
    required this.rotuloAcao,
    required this.aoConfirmar,
    this.carregando = false,
    this.perigo = true,
  });

  final String titulo;
  final String mensagem;
  final String rotuloAcao;
  final VoidCallback? aoConfirmar;
  final bool carregando;
  final bool perigo;

  @override
  Widget build(BuildContext context) {
    final cor = perigo ? CoresIdv.vermelho : StyleProjetos.laranja;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StyleProjetos.sidebarAbertaRaio)),
      child: Theme(
        data: temaIdv(Theme.of(context)),
        child: AvisosIdv(
          child: SizedBox(
            width: 460,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: cor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        perigo
                            ? FontAwesomeIcons.trashCan.data
                            : Icons.help_outline_rounded,
                        size: 19,
                        color: cor),
                  ),
                  const SizedBox(height: 16),
                  Text(titulo,
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: StyleProjetos.texto,
                          letterSpacing: -0.2)),
                  const SizedBox(height: 8),
                  Text(mensagem,
                      style: fonteIdv(
                          cor: StyleProjetos.textoSecundario, altura: 1.45)),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      BotaoSecundarioIdv(
                        rotulo: 'Cancelar',
                        aoTocar:
                            carregando ? null : () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      BotaoPrincipalIdv(
                        rotulo: rotuloAcao,
                        aoTocar: aoConfirmar,
                        carregando: carregando,
                        perigo: perigo,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rótulo dos campos (com * laranja nos obrigatórios).
class RotuloIdv extends StatelessWidget {
  const RotuloIdv(this.texto, {super.key, this.obrigatorio = false});
  final String texto;
  final bool obrigatorio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: texto,
          style: GoogleFonts.inter(
              color: StyleProjetos.texto,
              fontWeight: FontWeight.w600,
              fontSize: 14),
          children: [
            if (obrigatorio)
              const TextSpan(
                  text: ' *', style: TextStyle(color: StyleProjetos.laranja)),
          ],
        ),
      ),
    );
  }
}

/// Decoração dos campos de texto da IDV (fundo claro, borda fina, laranja
/// no foco e o erro embaixo da caixa).
InputDecoration decoracaoCampoIdv({String? dica, Widget? sufixo, Widget? prefixo}) {
  OutlineInputBorder borda(Color cor, [double largura = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cor, width: largura),
      );
  return InputDecoration(
    hintText: dica,
    hintStyle: fonteIdv(cor: CoresIdv.textoSecundario),
    filled: true,
    fillColor: CoresIdv.campo,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    suffixIcon: sufixo,
    prefixIcon: prefixo,
    border: borda(CoresIdv.borda),
    enabledBorder: borda(CoresIdv.borda),
    disabledBorder: borda(CoresIdv.borda),
    focusedBorder: borda(CoresIdv.laranja, 1.5),
    errorBorder: borda(CoresIdv.vermelho),
    focusedErrorBorder: borda(CoresIdv.vermelho, 1.5),
    errorStyle: fonteIdv(tamanho: 12, cor: CoresIdv.vermelho),
  );
}

/// Campo de texto com rótulo em cima. Em [somenteLeitura] mostra o valor
/// sem editar (modo de visualização).
class CampoIdv extends StatelessWidget {
  const CampoIdv({
    super.key,
    required this.rotulo,
    this.controle,
    this.valorInicial,
    this.dica,
    this.obrigatorio = false,
    this.somenteLeitura = false,
    this.validar,
    this.teclado,
    this.linhas = 1,
    this.formatadores,
    this.sufixo,
    this.aoMudar,
    this.ocultar = false,
    this.espacoAbaixo = 18,
  });

  final String rotulo;
  final TextEditingController? controle;

  /// Valor quando não há [controle] (visualização).
  final String? valorInicial;
  final String? dica;
  final bool obrigatorio;
  final bool somenteLeitura;

  /// Validação extra (o "obrigatório" já é feito aqui).
  final String? Function(String valor)? validar;
  final TextInputType? teclado;
  final int linhas;
  final List<TextInputFormatter>? formatadores;
  final Widget? sufixo;
  final ValueChanged<String>? aoMudar;
  final bool ocultar;
  final double espacoAbaixo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: espacoAbaixo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RotuloIdv(rotulo, obrigatorio: obrigatorio && !somenteLeitura),
          TextFormField(
            controller: controle,
            initialValue: controle == null ? (valorInicial ?? '') : null,
            readOnly: somenteLeitura,
            keyboardType: linhas > 1 ? TextInputType.multiline : teclado,
            minLines: linhas > 1 ? linhas : null,
            maxLines: linhas > 1 ? null : 1,
            obscureText: ocultar,
            inputFormatters: formatadores,
            onChanged: aoMudar,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: fonteIdv(),
            cursorColor: CoresIdv.azul,
            decoration: decoracaoCampoIdv(
              dica: somenteLeitura && (valorInicial ?? controle?.text ?? '').isEmpty
                  ? 'Não informado'
                  : dica,
              sufixo: sufixo,
            ),
            validator: somenteLeitura
                ? null
                : (v) {
                    final valor = (v ?? '').trim();
                    if (obrigatorio && valor.isEmpty) {
                      return 'Preencha o campo ${rotulo.toLowerCase()}';
                    }
                    if (valor.isEmpty) return null;
                    return validar?.call(valor);
                  },
          ),
        ],
      ),
    );
  }
}

/// Dois (ou mais) campos lado a lado; em painel estreito, um embaixo do
/// outro.
class LinhaCamposIdv extends StatelessWidget {
  const LinhaCamposIdv({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 440) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: children[i]),
          ],
        ],
      );
    });
  }
}

/// Título de grupo de campos dentro do painel ("Endereço", "Acesso").
class SecaoIdv extends StatelessWidget {
  const SecaoIdv(this.titulo, {super.key, this.descricao});
  final String titulo;
  final String? descricao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: StyleProjetos.texto)),
          if (descricao != null) ...[
            const SizedBox(height: 4),
            Text(descricao!,
                style: fonteIdv(
                    tamanho: 13, cor: StyleProjetos.textoSecundario)),
          ],
        ],
      ),
    );
  }
}
