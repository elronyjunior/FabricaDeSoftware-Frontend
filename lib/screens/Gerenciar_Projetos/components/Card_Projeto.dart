import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/Modal_novo_projeto.dart';
import 'package:fabrica_software_app/models/projeto.dart';
import 'package:fabrica_software_app/providers/projetos_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/components/visualizador_Projetos_Screen.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

class ProjectCard extends StatefulWidget {
  const ProjectCard({super.key, required this.projeto, this.aoPassarMouse});
  final Projeto projeto;

  /// Avisa a grade quando o mouse entra/sai, para ela desenhar este card por
  /// cima dos vizinhos enquanto ele está ampliado.
  final ValueChanged<bool>? aoPassarMouse;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hover = false;
  bool _pressionado = false;

  bool get _fixado =>
      context.watch<ProjetosProvider>().estaFixado(widget.projeto.id);

  String get _tipo {
    final tipo = (widget.projeto.tipo ?? '').trim();
    return tipo.isNotEmpty ? tipo : (widget.projeto.modeloProjeto ?? 'Geral');
  }

  IconData get _icone {
    final t = _tipo.toUpperCase();
    if (t.contains('WEB')) return Icons.language;
    if (t.contains('MOBILE') || t.contains('APP')) return Icons.smartphone;
    if (t.contains('API')) return Icons.code;
    if (t == 'AI' || t == 'IA' || t.contains('CHATBOT')) {
      return Icons.smart_toy_outlined;
    }
    if (t.contains('DESKTOP')) return Icons.monitor;
    if (t.contains('DATA')) return Icons.analytics;
    return Icons.folder_open;
  }

  /// Abre o projeto com uma transição simples: a tela aparece em fade.
  void _abrir() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) =>
            VisualizarProjetoScreen(projeto: widget.projeto),
        transitionsBuilder: (_, animacao, __, tela) => FadeTransition(
          opacity: CurvedAnimation(parent: animacao, curve: Curves.easeOut),
          child: tela,
        ),
      ),
    );
  }

  void _editar() {
    // Mesmo painel lateral da criação, só com as informações gerais.
    abrirModalNovoProjeto(context, projeto: widget.projeto);
  }

  void _excluir() {
    mostrarDialogo(
      context: context,
      builder: (ctx) => ConfirmacaoIdv(
        titulo: 'Excluir projeto',
        mensagem: '"${widget.projeto.nomeProjeto}" será excluído. '
            'Essa ação não pode ser desfeita.',
        rotuloAcao: 'Excluir projeto',
        aoConfirmar: () async {
          Navigator.pop(ctx);
          await context
              .read<ProjetosProvider>()
              .excluirProjeto(widget.projeto.id ?? 0);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.projeto;

    // Hover: o card só cresce. A cor e a sombra continuam iguais (o fundo é
    // translúcido, então uma sombra mais forte o deixaria mais escuro).
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hover = true);
        widget.aoPassarMouse?.call(true);
      },
      onExit: (_) {
        setState(() => _hover = false);
        widget.aoPassarMouse?.call(false);
      },
      // Clique: o card afunda um pouco enquanto está pressionado (no lugar
      // da onda do Material).
      child: AnimatedScale(
        scale: _pressionado ? 1.02 : (_hover ? 1.06 : 1),
        duration: Duration(milliseconds: _pressionado ? 90 : 220),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: StyleProjetos.superficie(),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(StyleProjetos.cardRaio),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _abrir,
              onHighlightChanged: (v) => setState(() => _pressionado = v),
              // Sem véu nem onda do Material no hover e no clique.
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 25, 25, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho: ícone, nome/cliente e status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconeTipo(icone: _icone),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                p.nomeProjeto,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StyleProjetos.cardTitulo,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.clienteNome ?? 'Cliente não informado',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StyleProjetos.cardCliente,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PillStatus(status: p.statusCalculado),
                      ],
                    ),
                    const SizedBox(height: 19),
                    Text(
                      p.descricao ?? 'Sem descrição',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: StyleProjetos.cardDescricao,
                    ),
                    const Spacer(),
                    // Rodapé: equipe e tipo (ou ações no hover)
                    SizedBox(
                      height: 30,
                      child: Row(
                        children: [
                          _Avatares(
                            nomes: [
                              for (final m in context
                                  .watch<ProjetosProvider>()
                                  .membrosDoProjeto(p.id))
                                m.nome
                            ],
                          ),
                          const Spacer(),
                          // No hover, o tipo dá lugar às ações (com fade).
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            // Encostado à direita: o padrão centraliza, e o
                            // tipo ficava no meio do rodapé quando a troca
                            // era interrompida (ex.: ao fixar, o card muda
                            // de lugar no meio da animação).
                            layoutBuilder: (atual, anteriores) => Stack(
                              alignment: Alignment.centerRight,
                              children: [
                                ...anteriores,
                                if (atual != null) atual,
                              ],
                            ),
                            child: _hover
                                ? Row(
                                    key: const ValueKey('acoes'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _Acao(
                                        icone: FontAwesomeIcons.thumbtack,
                                        dica: _fixado
                                            ? 'Desafixar do topo'
                                            : 'Fixar no topo',
                                        cor: _fixado
                                            ? StyleProjetos.laranja
                                            : StyleProjetos.textoSecundario,
                                        onTap: () => context
                                            .read<ProjetosProvider>()
                                            .alternarFixado(p.id),
                                      ),
                                      const SizedBox(width: 8),
                                      _Acao(
                                        icone: FontAwesomeIcons.penToSquare,
                                        dica: 'Editar',
                                        cor: StyleProjetos.azulEscuro,
                                        onTap: _editar,
                                      ),
                                      const SizedBox(width: 8),
                                      _Acao(
                                        icone: FontAwesomeIcons.trashCan,
                                        dica: 'Excluir',
                                        cor: _vermelho,
                                        onTap: _excluir,
                                      ),
                                    ],
                                  )
                                : Row(
                                    key: const ValueKey('tipo'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Fixado: o pino fica à vista.
                                      if (_fixado) ...[
                                        const Icon(FontAwesomeIcons.thumbtack,
                                            size: 13,
                                            color: StyleProjetos.laranja),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        _tipo.toUpperCase(),
                                        style: StyleProjetos.cardRodape,
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
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

// =====================================================================
// Componentes do card
// =====================================================================

class _IconeTipo extends StatelessWidget {
  const _IconeTipo({required this.icone});
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: StyleProjetos.azulEscuro,
        shape: BoxShape.circle,
      ),
      child: Icon(icone, color: Colors.white, size: 24),
    );
  }
}

class _PillStatus extends StatelessWidget {
  const _PillStatus({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final estilo = EstiloStatus.de(status);
    return Container(
      height: 22,
      constraints: const BoxConstraints(minWidth: 62),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: estilo.gradiente,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        status,
        style: StyleProjetos.pill.copyWith(color: estilo.corTexto),
      ),
    );
  }
}

/// Duas pessoas do projeto sobrepostas e "+N" para o restante da equipe
/// (ex.: 5 membros = 2 avatares e "+3").
class _Avatares extends StatelessWidget {
  const _Avatares({required this.nomes});

  final List<String> nomes;

  static const _raio = 13.0;
  static const _sobreposicao = 9.0;

  @override
  Widget build(BuildContext context) {
    if (nomes.isEmpty) return const _Avatar();

    final visiveis = nomes.take(2).toList();
    final restantes = nomes.length - visiveis.length;

    return Tooltip(
      message: nomes.join('\n'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width:
                _raio * 2 + (visiveis.length - 1) * (_raio * 2 - _sobreposicao),
            height: _raio * 2,
            child: Stack(
              children: [
                for (var i = 0; i < visiveis.length; i++)
                  Positioned(
                    left: i * (_raio * 2 - _sobreposicao),
                    child: _Avatar(nome: visiveis[i], indice: i),
                  ),
              ],
            ),
          ),
          if (restantes > 0) ...[
            const SizedBox(width: 6),
            Text('+$restantes', style: StyleProjetos.cardRodape),
          ],
        ],
      ),
    );
  }
}

/// Avatar com as iniciais da pessoa (o cadastro ainda não tem foto).
/// Sem nome: ícone de pessoa (projeto sem equipe).
class _Avatar extends StatelessWidget {
  const _Avatar({this.nome, this.indice = 0});
  final String? nome;
  final int indice;

  static const _cores = [StyleProjetos.azulEscuro, Color(0xFF4A4E6E)];

  String get _iniciais {
    final partes =
        nome!.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (nome == null) {
      return const CircleAvatar(
        radius: 12,
        backgroundColor: Color(0xFFD9DBE5),
        child:
            Icon(Icons.person, size: 15, color: StyleProjetos.textoSecundario),
      );
    }
    return Container(
      width: _Avatares._raio * 2,
      height: _Avatares._raio * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _cores[indice % _cores.length],
        shape: BoxShape.circle,
        // Anel claro separa os avatares sobrepostos.
        border: Border.all(color: const Color(0xFFEEF0F6), width: 2),
      ),
      child: Text(
        _iniciais,
        style: StyleProjetos.cardRodape.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Vermelho da IDV (o mesmo da etiqueta "Atrasado").
const _vermelho = Color(0xFFD62A1E);

/// Ação do card: só o ícone, na cor da ação. No hover ele cresce, sobe um
/// pouco e a cor fica mais forte.
class _Acao extends StatefulWidget {
  const _Acao({
    required this.icone,
    required this.dica,
    required this.cor,
    required this.onTap,
  });

  final IconData icone;
  final String dica;
  final Color cor;
  final VoidCallback onTap;

  @override
  State<_Acao> createState() => _AcaoState();
}

class _AcaoState extends State<_Acao> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    const duracao = Duration(milliseconds: 180);
    return Tooltip(
      message: widget.dica,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          // Área de clique maior que o ícone.
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(6),
            child: AnimatedSlide(
              offset: Offset(0, _hover ? -0.12 : 0),
              duration: duracao,
              curve: Curves.easeOutCubic,
              child: AnimatedScale(
                scale: _hover ? 1.22 : 1,
                duration: duracao,
                curve: Curves.easeOutCubic,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: _hover ? widget.cor : widget.cor.withOpacity(0.7),
                  ),
                  duration: duracao,
                  builder: (_, cor, __) =>
                      FaIcon(widget.icone, size: 16, color: cor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
