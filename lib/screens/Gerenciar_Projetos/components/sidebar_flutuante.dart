import 'dart:async';
import 'dart:ui';

import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Menu lateral em pílula de vidro.
/// Fechado: só ícones (89px). Aberto (hover ou toque no logo): 400px,
/// com nomes, por cima do conteúdo e desfocando o que está atrás.
class SidebarFlutuante extends StatefulWidget {
  const SidebarFlutuante({
    super.key,
    required this.indiceAtivo,
    required this.onSelecionar,
    this.onAlternarTema,
    this.onPerfil,
    this.onSair,
    this.sempreAberta = false,
  });

  final int indiceAtivo;
  final ValueChanged<int> onSelecionar;
  final VoidCallback? onAlternarTema;
  final VoidCallback? onPerfil;
  final VoidCallback? onSair;

  /// Use `true` quando o menu estiver dentro de um Drawer (celular).
  final bool sempreAberta;

  static const itens = [
    (icone: Icons.account_tree, rotulo: 'Projetos'),
    (icone: Icons.groups, rotulo: 'Equipe'),
    (icone: Icons.file_copy, rotulo: 'Relatórios'),
    (icone: Icons.manage_accounts, rotulo: 'Gestão de usuários'),
    (icone: Icons.how_to_reg, rotulo: 'Gestão de clientes'),
    (icone: Icons.memory, rotulo: 'Gestão de tecnologias'),
  ];

  @override
  State<SidebarFlutuante> createState() => _SidebarFlutuanteState();
}

class _SidebarFlutuanteState extends State<SidebarFlutuante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 280),
    value: widget.sempreAberta ? 1 : 0,
  );

  late final Animation<double> _animacao = CurvedAnimation(
    parent: _controle,
    curve: Curves.easeOutQuart,
    reverseCurve: Curves.easeInOutCubic,
  );

  /// Pequeno atraso para o menu não abrir quando o mouse só passa por cima.
  Timer? _atraso;

  void _abrir() {
    if (widget.sempreAberta) return;
    _atraso?.cancel();
    _atraso = Timer(const Duration(milliseconds: 90), _controle.forward);
  }

  void _fechar() {
    if (widget.sempreAberta) return;
    _atraso?.cancel();
    _controle.reverse();
  }

  /// Fecha o menu e executa a ação do item tocado.
  void _executar(VoidCallback? acao) {
    _fechar();
    acao?.call();
  }

  @override
  void dispose() {
    _atraso?.cancel();
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _abrir(),
      onExit: (_) => _fechar(),
      child: AnimatedBuilder(
        animation: _animacao,
        builder: (context, _) => _painel(_animacao.value),
      ),
    );
  }

  Widget _painel(double t) {
    final largura = lerpDouble(
        StyleProjetos.sidebarLargura, StyleProjetos.sidebarAbertaLargura, t)!;
    final raio = BorderRadius.circular(lerpDouble(
        StyleProjetos.sidebarRaio, StyleProjetos.sidebarAbertaRaio, t)!);
    final desfoque = lerpDouble(16, 28, t)!;

    // Vidro claro translúcido (fechado e aberto): gradiente branco suave
    // + desfoque do que está por trás + borda clara.
    final gradiente = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(lerpDouble(0.60, 0.55, t)!),
        Colors.white.withOpacity(lerpDouble(0.35, 0.30, t)!),
      ],
    );

    return Container(
      width: largura,
      decoration: BoxDecoration(
        borderRadius: raio,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C1F3A).withOpacity(0.08 + 0.06 * t),
            blurRadius: 14 + 16 * t,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: raio,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: desfoque, sigmaY: desfoque),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradiente,
              borderRadius: raio,
            ),
            // Material transparente: necessário para o efeito de toque
            // aparecer por cima do vidro.
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 40, 0, 52),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Linha(
                      t: t,
                      inicio: Image.asset(
                        'assets/image/tegra_logo_icon.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                      larguraInicio: 32,
                      rotulo: 'Tegra Software',
                      estiloRotulo: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: StyleProjetos.texto,
                      ),
                      // Só a marca: não é botão (o item ativo é o ícone
                      // laranja), então não tem toque nem destaque.
                    ),
                    const SizedBox(height: 31),
                    for (var i = 0; i < SidebarFlutuante.itens.length; i++) ...[
                      _Item(
                        t: t,
                        icone: SidebarFlutuante.itens[i].icone,
                        rotulo: SidebarFlutuante.itens[i].rotulo,
                        ativo: i == widget.indiceAtivo,
                        onTap: () => _executar(() => widget.onSelecionar(i)),
                      ),
                      if (i < SidebarFlutuante.itens.length - 1)
                        const SizedBox(height: 17),
                    ],
                    const Spacer(),
                    _Item(
                      t: t,
                      icone: Icons.dark_mode,
                      rotulo: 'Tema de preferência',
                      onTap: () => _executar(widget.onAlternarTema),
                    ),
                    const SizedBox(height: 16),
                    _Item(
                      t: t,
                      icone: Icons.person,
                      rotulo: 'Perfil',
                      onTap: () => _executar(widget.onPerfil),
                    ),
                    const SizedBox(height: 32),
                    _Item(
                      t: t,
                      icone: Icons.door_front_door,
                      rotulo: 'Sair',
                      negrito: true,
                      onTap: () => _executar(widget.onSair),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.t,
    required this.icone,
    required this.rotulo,
    required this.onTap,
    this.ativo = false,
    this.negrito = false,
  });

  final double t;
  final IconData icone;
  final String rotulo;
  final bool ativo;
  final bool negrito;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Linha(
      t: t,
      inicio: Icon(
        icone,
        size: 24,
        color: ativo ? StyleProjetos.laranja : StyleProjetos.azulEscuro,
      ),
      larguraInicio: 24,
      rotulo: rotulo,
      estiloRotulo: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: negrito ? FontWeight.w600 : FontWeight.w400,
        color: ativo ? StyleProjetos.laranja : StyleProjetos.texto,
      ),
      onTap: onTap,
    );
  }
}

/// Ícone centralizado na coluna de 89px + rótulo que entra
/// deslizando e aparecendo quando o menu abre.
class _Linha extends StatelessWidget {
  const _Linha({
    required this.t,
    required this.inicio,
    required this.larguraInicio,
    required this.rotulo,
    required this.estiloRotulo,
    this.onTap,
  });

  final double t;
  final Widget inicio;
  final double larguraInicio;
  final String rotulo;
  final TextStyle estiloRotulo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final recuo = (StyleProjetos.sidebarLargura - larguraInicio) / 2;
    // O texto só começa a aparecer depois de 35% da abertura.
    final visibilidade =
        Curves.easeOut.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));

    final conteudo = SizedBox(
      height: larguraInicio + 12,
      child: Row(
        children: [
          SizedBox(width: recuo - 8),
          inicio,
          // Rótulo começa logo depois da coluna de ícones do menu fechado
          // (a linha tem 8 de margem de cada lado).
          SizedBox(
              width: StyleProjetos.sidebarLargura - 8 - recuo - larguraInicio),
          Flexible(
            child: Opacity(
              opacity: visibilidade,
              child: Transform.translate(
                offset: Offset(-10 * (1 - visibilidade), 0),
                child: Text(
                  rotulo,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: estiloRotulo,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // Sem ação (ex.: a marca da Tegra): só o conteúdo, sem toque nem destaque.
      child: onTap == null
          ? conteudo
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: StyleProjetos.azulEscuro.withOpacity(0.06 * t),
              splashColor: StyleProjetos.azulEscuro.withOpacity(0.08),
              highlightColor: StyleProjetos.azulEscuro.withOpacity(0.04),
              // Foco só aparece com o menu aberto (o item ativo já é o
              // ícone laranja; fechado, não fica uma caixa cinza no ícone).
              focusColor: StyleProjetos.azulEscuro.withOpacity(0.06 * t),
              child: conteudo,
            ),
    );
  }
}
