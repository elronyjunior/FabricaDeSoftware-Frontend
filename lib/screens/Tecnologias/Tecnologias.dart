import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Gestao/pagina_gestao.dart';
import 'package:fabrica_software_app/models/tecnologia.dart';
import 'package:fabrica_software_app/providers/tecnologias_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Tecnologias/components/Tecnologia_modal.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

/// Gestão de Tecnologias em cards no mesmo formato dos cards de Projetos,
/// com a barra padrão das telas de gestão (Filtro lateral, pesquisa,
/// ordenar, recarregar e contador) e rolagem infinita.
class Tecnologias extends StatefulWidget {
  const Tecnologias({super.key});

  @override
  State<Tecnologias> createState() => _TecnologiasState();
}

class _TecnologiasState extends State<Tecnologias> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TecnologiasProvider>().carregarTecnologias();
    });
  }

  static String _categoria(Tecnologia t) {
    final c = (t.categoria ?? '').trim();
    return c.isEmpty ? 'Sem categoria' : c;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TecnologiasProvider>();

    return PaginaGestao<Tecnologia>(
      titulo: 'Gestão de Tecnologias',
      rotuloNovo: 'Nova Tecnologia',
      aoNovo: () => _abrirModalCriarTecnologia(context),
      tituloLista: 'Lista de Tecnologias',
      singular: 'tecnologia',
      plural: 'tecnologias',
      feminino: true,
      itens: provider.tecnologias ?? const [],
      carregando: provider.isLoading,
      erro: provider.error,
      aoRecarregar: provider.carregarTecnologias,
      nome: (t) => t.nome,
      textoBusca: (t) => '${t.nome} ${t.categoria ?? ''} ${t.descricao ?? ''}',
      rotuloFiltro: 'Categoria',
      valorFiltro: _categoria,
      colunasGrade: 4,
      card: (t) => _CardTecnologia(tecnologia: t, categoria: _categoria(t)),
    );
  }
}

// =====================================================================
// Card de tecnologia: mesma estrutura do card de projeto
// =====================================================================

class _CardTecnologia extends StatefulWidget {
  const _CardTecnologia({required this.tecnologia, required this.categoria});
  final Tecnologia tecnologia;
  final String categoria;

  @override
  State<_CardTecnologia> createState() => _CardTecnologiaState();
}

class _CardTecnologiaState extends State<_CardTecnologia> {
  bool _hover = false;
  bool _pressionado = false;

  /// Ícone pela categoria (como o ícone pelo tipo no card de projeto).
  IconData get _icone {
    final c = widget.categoria.toLowerCase();
    if (c.contains('banco') || c.contains('dados')) return Icons.storage_rounded;
    if (c.contains('linguagem')) return Icons.code_rounded;
    if (c == 'ia' || c.contains('intelig')) return Icons.smart_toy_outlined;
    if (c.contains('plataforma') || c.contains('cloud') || c.contains('nuvem')) {
      return Icons.cloud_outlined;
    }
    if (c.contains('framework') || c.contains('biblioteca')) {
      return Icons.layers_outlined;
    }
    return Icons.memory_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tecnologia;
    final descricao = (t.descricao ?? '').trim();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _pressionado ? 1.02 : (_hover ? 1.06 : 1),
        duration: Duration(milliseconds: _pressionado ? 90 : 220),
        curve: Curves.easeOutCubic,
        child: Container(
          height: StyleProjetos.cardAltura,
          decoration: StyleProjetos.superficie(),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(StyleProjetos.cardRaio),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  _abrirModalTecnologia(context, t, TecnologiaModalMode.view),
              onHighlightChanged: (v) => setState(() => _pressionado = v),
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 25, 25, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho: ícone, nome e categoria
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: StyleProjetos.azulEscuro,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_icone, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(t.nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: StyleProjetos.cardTitulo),
                              const SizedBox(height: 4),
                              Text(widget.categoria,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: StyleProjetos.cardCliente),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 19),
                    Text(
                      descricao.isEmpty ? 'Sem descrição' : descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: StyleProjetos.cardDescricao,
                    ),
                    const Spacer(),
                    // Rodapé: categoria (ou ações no hover), como em Projetos
                    SizedBox(
                      height: 30,
                      child: Row(
                        children: [
                          const Spacer(),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            // Encostado à direita (o padrão centraliza).
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
                                        icone: FontAwesomeIcons.penToSquare,
                                        dica: 'Editar',
                                        cor: StyleProjetos.azulEscuro,
                                        aoTocar: () => _abrirModalTecnologia(
                                            context,
                                            t,
                                            TecnologiaModalMode.edit),
                                      ),
                                      const SizedBox(width: 8),
                                      _Acao(
                                        icone: FontAwesomeIcons.trashCan,
                                        dica: 'Excluir',
                                        cor: const Color(0xFFD62A1E),
                                        aoTocar: () => _abrirModalTecnologia(
                                            context,
                                            t,
                                            TecnologiaModalMode.delete),
                                      ),
                                    ],
                                  )
                                : Text(
                                    widget.categoria.toUpperCase(),
                                    key: const ValueKey('categoria'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: StyleProjetos.cardRodape,
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

/// Ação do card: só o ícone, que cresce e ganha cor no hover (igual ao
/// card de projeto).
class _Acao extends StatefulWidget {
  const _Acao({
    required this.icone,
    required this.dica,
    required this.cor,
    required this.aoTocar,
  });

  final IconData icone;
  final String dica;
  final Color cor;
  final VoidCallback aoTocar;

  @override
  State<_Acao> createState() => _AcaoState();
}

class _AcaoState extends State<_Acao> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.dica,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.aoTocar,
          child: AnimatedScale(
            scale: _hover ? 1.18 : 1,
            duration: const Duration(milliseconds: 150),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(widget.icone,
                  size: 17,
                  color: _hover ? widget.cor : widget.cor.withOpacity(0.75)),
            ),
          ),
        ),
      ),
    );
  }
}

void _abrirModalTecnologia(
    BuildContext context, Tecnologia tecnologia, TecnologiaModalMode modo) {
  mostrarDialogo(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => TecnologiaModal(mode: modo, tecnologia: tecnologia),
  );
}

void _abrirModalCriarTecnologia(BuildContext context) {
  mostrarDialogo(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const TecnologiaModal(mode: TecnologiaModalMode.create),
  );
}
