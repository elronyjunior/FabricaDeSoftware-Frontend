import 'package:fabrica_software_app/Widgets/Barra_lateral/Barra_Lateral.dart';
import 'package:fabrica_software_app/Widgets/Gestao/pagina_gestao.dart';
import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/models/projeto.dart';
import 'package:fabrica_software_app/models/usuario.dart';
import 'package:fabrica_software_app/providers/equipes_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/components/escala_design.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// =====================================================================
// Gestão de Equipes: os projetos (cada um com a sua equipe) à esquerda e
// as pessoas à direita. As pessoas são os usuários de "Gestão de usuários"
// (cadastro e edição ficam lá); aqui só se monta a equipe, arrastando uma
// pessoa para cima de um projeto.
// =====================================================================

class GerenciarEquipesScreen extends StatelessWidget {
  const GerenciarEquipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EquipesProvider>(
      create: (_) => EquipesProvider()..carregarDados(),
      child: const _TelaEquipes(),
    );
  }
}

class _TelaEquipes extends StatefulWidget {
  const _TelaEquipes();

  @override
  State<_TelaEquipes> createState() => _TelaEquipesState();
}

class _TelaEquipesState extends State<_TelaEquipes> {
  final _buscaProjetos = TextEditingController();
  final _buscaPessoas = TextEditingController();

  @override
  void dispose() {
    _buscaProjetos.dispose();
    _buscaPessoas.dispose();
    super.dispose();
  }

  static String _semAcento(String texto) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const para = 'aaaaaeeeeiiiiooooouuuucn';
    final saida = StringBuffer();
    for (final c in texto.trim().toLowerCase().split('')) {
      final i = de.indexOf(c);
      saida.write(i >= 0 ? para[i] : c);
    }
    return saida.toString();
  }

  static bool _contem(String texto, TextEditingController busca) {
    final termo = _semAcento(busca.text);
    return termo.isEmpty || _semAcento(texto).contains(termo);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = LayoutPrincipal.menuFixo(context);
    return Scaffold(
      drawer: BarraLateral.drawer(context),
      backgroundColor: desktop ? Colors.transparent : null,
      body: DecoratedBox(
        decoration: desktop
            ? const BoxDecoration()
            : const BoxDecoration(gradient: StyleProjetos.gradienteFundo),
        child: SafeArea(
          child: desktop
              ? EscalaDesign(
                  larguraBase: LayoutPrincipal.larguraBase -
                      LayoutPrincipal.recuoConteudo,
                  child: _conteudo(true),
                )
              : _conteudo(false),
        ),
      ),
    );
  }

  Widget _conteudo(bool desktop) {
    final provider = context.watch<EquipesProvider>();
    return Padding(
      padding: desktop
          ? const EdgeInsets.fromLTRB(25, 62, 36, 0)
          : const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!desktop)
                Builder(
                  builder: (ctx) => IconButton(
                    icon:
                        const Icon(Icons.menu, color: StyleProjetos.azulEscuro),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              Expanded(
                child: Text('Gestão de Equipes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: desktop
                        ? StyleProjetos.titulo
                        : StyleProjetos.titulo.copyWith(fontSize: 24)),
              ),
            ],
          ),
          SizedBox(height: desktop ? 44 : 20),
          Expanded(child: _corpo(provider)),
        ],
      ),
    );
  }

  Widget _corpo(EquipesProvider provider) {
    final semDados = provider.projetos.isEmpty && provider.pessoas.isEmpty;
    if (provider.isLoading && semDados) {
      return const Center(
          child: CircularProgressIndicator(color: StyleProjetos.laranja));
    }
    if (provider.error != null && semDados) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Não foi possível carregar as equipes.',
                style: StyleProjetos.cardTitulo),
            const SizedBox(height: 4),
            Text(provider.error!, style: StyleProjetos.cardRodape),
            TextButton(
                onPressed: provider.carregarDados,
                child: const Text('Tentar de novo')),
          ],
        ),
      );
    }

    final projetos = provider.projetos
        .where((p) =>
            _contem('${p.nomeProjeto} ${p.clienteNome ?? ''}', _buscaProjetos))
        .toList();
    final pessoas = provider.pessoas
        .where((u) => _contem('${u.nome} ${u.email}', _buscaPessoas))
        .toList();

    final colunaProjetos = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Projetos', style: StyleProjetos.subtitulo),
            const SizedBox(width: 10),
            Text('${projetos.length}', style: StyleProjetos.cardRodape),
            const Spacer(),
            SizedBox(
              width: 280,
              child: CampoPesquisaGestao(
                  controle: _buscaProjetos, aoMudar: (_) => setState(() {})),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: projetos.isEmpty
              ? Center(
                  child: Text(
                      provider.projetos.isEmpty
                          ? 'Nenhum projeto cadastrado.'
                          : 'Nenhum projeto encontrado.',
                      style: StyleProjetos.cardCliente))
              // Um painel só, com os projetos separados por divisórias.
              : Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Container(
                    decoration: StyleProjetos.painel(),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: projetos.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, color: StyleProjetos.divisoria),
                      itemBuilder: (context, i) => _ProjetoEquipe(
                        key: ValueKey(projetos[i].id),
                        projeto: projetos[i],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );

    final painelPessoas = _PainelPessoas(
      pessoas: pessoas,
      total: provider.pessoas.length,
      busca: _buscaPessoas,
      aoBuscar: () => setState(() {}),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 860) {
        return Column(
          children: [
            Expanded(flex: 3, child: colunaProjetos),
            const SizedBox(height: 16),
            Expanded(flex: 2, child: painelPessoas),
            const SizedBox(height: 16),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: colunaProjetos),
          const SizedBox(width: 28),
          SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: painelPessoas,
            ),
          ),
        ],
      );
    });
  }
}

// =====================================================================
// Projeto com a equipe
// =====================================================================

class _ProjetoEquipe extends StatefulWidget {
  const _ProjetoEquipe({super.key, required this.projeto});
  final Projeto projeto;

  @override
  State<_ProjetoEquipe> createState() => _ProjetoEquipeState();
}

class _ProjetoEquipeState extends State<_ProjetoEquipe> {
  bool _aberto = false;

  Future<void> _adicionar(Usuario pessoa) async {
    final provider = context.read<EquipesProvider>();
    final id = widget.projeto.id;
    if (id == null) return;
    if (provider.usuarioNoProjeto(id, pessoa)) {
      avisar(context, '${pessoa.nome} já está nesta equipe.',
          tipo: TipoAviso.info);
      return;
    }
    setState(() => _aberto = true);
    final erro = await provider.adicionarUsuario(id, pessoa);
    if (!mounted) return;
    avisar(context, erro ?? '${pessoa.nome} entrou na equipe.',
        tipo: erro == null ? TipoAviso.sucesso : TipoAviso.erro);
  }

  Future<void> _remover(MembroEquipe m) async {
    final id = widget.projeto.id;
    final contribuidorId = m.contribuidor.id;
    if (id == null || contribuidorId == null) return;
    final erro =
        await context.read<EquipesProvider>().removerMembro(id, contribuidorId);
    if (!mounted) return;
    avisar(context, erro ?? '${m.nome} saiu da equipe.',
        tipo: erro == null ? TipoAviso.sucesso : TipoAviso.erro);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.projeto;
    final membros =
        context.watch<EquipesProvider>().membrosDoProjeto(p.id ?? -1);

    return DragTarget<Usuario>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _adicionar(d.data),
      builder: (context, candidatos, _) {
        final soltando = candidatos.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // Soltando uma pessoa: fundo laranja claro e faixa laranja à
          // esquerda (a linha fica dentro do painel, sem borda própria).
          decoration: BoxDecoration(
            color: soltando ? const Color(0xFFFFF4EC) : null,
            border: Border(
              left: BorderSide(
                color: soltando ? StyleProjetos.laranja : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _aberto = !_aberto),
                  hoverColor: StyleProjetos.linhaHover,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nomeProjeto,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: StyleProjetos.cardTitulo),
                              const SizedBox(height: 2),
                              Text(
                                soltando
                                    ? 'Solte para adicionar à equipe'
                                    : (p.clienteNome ?? 'Sem cliente'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: soltando
                                    ? StyleProjetos.cardRodape.copyWith(
                                        color: StyleProjetos.laranja,
                                        fontWeight: FontWeight.w600)
                                    : StyleProjetos.cardRodape,
                              ),
                            ],
                          ),
                        ),
                        EtiquetaGestao(
                          membros.isEmpty
                              ? 'Sem equipe'
                              : membros.length == 1
                                  ? '1 pessoa'
                                  : '${membros.length} pessoas',
                          fundo: membros.isEmpty
                              ? const Color(0x140F1030)
                              : const Color(0xFFA9B4F0),
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: _aberto ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: StyleProjetos.azulEscuro),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_aberto
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: membros.isEmpty
                                ? Text(
                                    'Ninguém ainda. Arraste uma pessoa da '
                                    'lista para cá.',
                                    style: StyleProjetos.cardRodape)
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final m in membros)
                                        _ChipMembro(
                                          nome: m.nome,
                                          aoRemover: () => _remover(m),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChipMembro extends StatelessWidget {
  const _ChipMembro({required this.nome, required this.aoRemover});
  final String nome;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      decoration: BoxDecoration(
        color: CoresIdv.campo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CoresIdv.borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(nome, tamanho: 26),
          const SizedBox(width: 8),
          Text(nome, style: fonteIdv(tamanho: 13, peso: FontWeight.w500)),
          const SizedBox(width: 2),
          InkResponse(
            onTap: aoRemover,
            radius: 14,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  size: 15, color: CoresIdv.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Pessoas (usuários do sistema)
// =====================================================================

class _PainelPessoas extends StatelessWidget {
  const _PainelPessoas({
    required this.pessoas,
    required this.total,
    required this.busca,
    required this.aoBuscar,
  });

  final List<Usuario> pessoas;
  final int total;
  final TextEditingController busca;
  final VoidCallback aoBuscar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: StyleProjetos.painel(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pessoas', style: StyleProjetos.subtitulo),
          const SizedBox(height: 2),
          Text('Arraste até um projeto',
              style: StyleProjetos.cardRodape.copyWith(fontSize: 12.5)),
          const SizedBox(height: 14),
          CampoPesquisaGestao(controle: busca, aoMudar: (_) => aoBuscar()),
          const SizedBox(height: 8),
          Expanded(
            child: pessoas.isEmpty
                ? Center(
                    child: Text(
                      total == 0
                          ? 'Nenhum usuário cadastrado.\nCadastre em Gestão de usuários.'
                          : 'Ninguém encontrado.',
                      textAlign: TextAlign.center,
                      style: StyleProjetos.cardRodape,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: pessoas.length,
                    itemBuilder: (context, i) => _Pessoa(
                      key: ValueKey(pessoas[i].id),
                      usuario: pessoas[i],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// "admin" -> "Admin" (o nível do usuário, como cargo).
String _rotuloNivel(String? nivel) {
  final n = (nivel ?? '').trim();
  if (n.isEmpty) return 'Usuário';
  return n[0].toUpperCase() + n.substring(1).toLowerCase();
}

class _Pessoa extends StatelessWidget {
  const _Pessoa({super.key, required this.usuario});
  final Usuario usuario;

  Widget _linha({bool arrastando = false, int projetos = 0}) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: arrastando ? StyleProjetos.fundoCard : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: arrastando
            ? [
                BoxShadow(
                  color: const Color(0xFF1C1F3A).withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          _Avatar(usuario.nome),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usuario.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: fonteIdv(tamanho: 14, peso: FontWeight.w500)),
                Text(
                  arrastando
                      ? _rotuloNivel(usuario.nivel)
                      : '${_rotuloNivel(usuario.nivel)} · '
                          '${projetos == 0 ? 'sem projeto' : projetos == 1 ? '1 projeto' : '$projetos projetos'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: fonteIdv(tamanho: 12, cor: CoresIdv.textoSecundario),
                ),
              ],
            ),
          ),
          const Icon(Icons.drag_indicator_rounded,
              size: 18, color: Color(0x660F1030)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projetos = context.watch<EquipesProvider>().projetosDoUsuario(usuario);
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Draggable<Usuario>(
        data: usuario,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 260, child: _linha(arrastando: true)),
        ),
        childWhenDragging:
            Opacity(opacity: 0.35, child: _linha(projetos: projetos)),
        child: _linha(projetos: projetos),
      ),
    );
  }
}

/// Avatar redondo com as iniciais (mesmo estilo do menu lateral).
class _Avatar extends StatelessWidget {
  const _Avatar(this.nome, {this.tamanho = 34});
  final String nome;
  final double tamanho;

  String get _iniciais {
    final partes =
        nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (partes.first[0] + ultima).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
          color: StyleProjetos.azulEscuro, shape: BoxShape.circle),
      child: Text(_iniciais,
          style: GoogleFonts.inter(
              fontSize: tamanho * 0.36,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
    );
  }
}
