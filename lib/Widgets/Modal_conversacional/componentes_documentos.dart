import 'package:flutter/material.dart';

import 'controlador_conversa.dart';
import 'estilo_conversa.dart';
import 'perguntas.dart';

// =====================================================================
// Pop-up de confirmação (fechar o projeto, excluir requisito, pendentes)
// =====================================================================

/// Pop-up pequeno usado em todas as confirmações do modal.
/// Devolve `true` em [confirmar], `false` em [cancelar] e `null` se fechado.
Future<bool?> mostrarConfirmacao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String cancelar = 'Cancelar',
  required String confirmar,
  bool perigo = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(titulo,
          style: EstiloConversa.fonte(tamanho: 18, peso: FontWeight.w600)),
      content: Text(
        mensagem,
        style: EstiloConversa.fonte(
            tamanho: 14, cor: EstiloConversa.textoSecundario),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(
              foregroundColor: EstiloConversa.textoSecundario),
          child: Text(cancelar),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
              foregroundColor: perigo ? Colors.red : EstiloConversa.laranja),
          child: Text(confirmar),
        ),
      ],
    ),
  );
}

// =====================================================================
// Bloco de requisitos
// =====================================================================

/// Bloco largo de cards de requisitos. Lê a mesma lista do formulário, então
/// mostra sempre a versão atual (no chat e no documento).
class BlocoRequisitos extends StatefulWidget {
  const BlocoRequisitos({
    super.key,
    required this.controlador,
    required this.chavesCards,
  });

  final ControladorConversa controlador;

  /// Chave de cada card (para rolar até um card pendente).
  final Map<String, GlobalKey> chavesCards;

  @override
  State<BlocoRequisitos> createState() => _BlocoRequisitosState();
}

class _BlocoRequisitosState extends State<BlocoRequisitos> {
  final Set<String> _abertos = {};

  ControladorConversa get _c => widget.controlador;

  Future<void> _excluir(Map<String, dynamic> r) async {
    final ok = await mostrarConfirmacao(
      context,
      titulo: 'Excluir requisito?',
      mensagem: 'Tem certeza que deseja excluir "${r['titulo']}"?',
      confirmar: 'Excluir',
      perigo: true,
    );
    if (ok == true) _c.excluirRequisito(r[chaveIdRequisito]);
  }

  @override
  Widget build(BuildContext context) {
    final lista = _c.dados.requisitos;
    final contagem = _c.contagemRequisitos;
    final removidos = _c.requisitosRemovidos;
    // Muitos requisitos: agrupados por tipo, para o chat não virar uma
    // rolagem infinita (os cards já ficam fechados).
    final agrupar = lista.length > 6;

    final cards = <Widget>[];
    if (lista.isEmpty &&
        removidos.isEmpty &&
        _c.editandoRequisito != idNovoRequisito) {
      cards.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          _c.gerando
              ? 'Gerando requisitos...'
              : 'Nenhum requisito ainda. Use a barra abaixo para adicionar '
                  'manualmente ou ative a IA.',
          style: EstiloConversa.fonte(
              tamanho: 13, cor: EstiloConversa.textoSecundario),
        ),
      ));
    } else if (agrupar) {
      for (final (rotulo, funcional) in [
        ('Funcionais', true),
        ('Não funcionais', false),
      ]) {
        final grupo = [
          for (final r in lista)
            if (ControladorConversa.ehFuncional(r) == funcional) r
        ];
        if (grupo.isEmpty) continue;
        cards.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Text('$rotulo (${grupo.length})'.toUpperCase(),
              style: EstiloConversa.fonte(
                      tamanho: 10.5,
                      peso: FontWeight.w600,
                      cor: EstiloConversa.textoSecundario)
                  .copyWith(letterSpacing: 0.6)),
        ));
        cards.addAll(grupo.map(_card));
      }
    } else {
      cards.addAll(lista.map(_card));
    }
    cards.addAll(removidos.map((r) => _card(r, removido: true)));
    // Card novo, criado direto no bloco ("Adicionar manualmente" ou Enter
    // na barra com a IA desligada).
    if (_c.editandoRequisito == idNovoRequisito) {
      cards.add(_EditorRequisito(
        key: widget.chavesCards.putIfAbsent(idNovoRequisito, GlobalKey.new),
        controlador: _c,
        requisito: null,
      ));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(
        color: EstiloConversa.balaoSistema,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: título e contadores.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Requisitos · v${_c.versaoRequisitos < 1 ? 1 : _c.versaoRequisitos}',
                style: EstiloConversa.fonte(peso: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              _Contador('Funcionais', '${contagem.funcionais}'),
              _Contador('Não funcionais', '${contagem.naoFuncionais}'),
              _Contador('Aprovados', '${contagem.aprovados}/${contagem.total}',
                  destaque: contagem.total > 0 &&
                      contagem.aprovados == contagem.total),
            ],
          ),
          const SizedBox(height: 12),
          ...cards,
          const SizedBox(height: 4),
          // Rodapé.
          Wrap(
            spacing: 2,
            children: [
              _AcaoBloco('Aprovar todos', Icons.done_all,
                  lista.isEmpty || _c.gerando ? null : _c.aprovarTodos),
              _AcaoBloco('Adicionar manualmente', Icons.add,
                  _c.gerando ? null : _c.abrirRequisitoManual),
              if ((_c.dados.escopo ?? '').trim().isNotEmpty)
                _AcaoBloco(
                    _c.versaoRequisitos == 0
                        ? 'Gerar com IA'
                        : 'Gerar novamente',
                    Icons.refresh,
                    _c.gerando ? null : _c.gerarRequisitos),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> r, {bool removido = false}) {
    final id = r[chaveIdRequisito] as String;
    // Lápis: o próprio card vira o formulário.
    if (!removido && _c.editandoRequisito == id) {
      return _EditorRequisito(
        key: widget.chavesCards.putIfAbsent(id, GlobalKey.new),
        controlador: _c,
        requisito: r,
      );
    }
    final aberto = _abertos.contains(id) && !removido;
    final aprovado = r['is_approved'] == true;
    final marca = removido ? null : _c.marcaDe(id);
    final destaque = _c.destaqueRequisito == id;
    final editando = _c.editandoRequisito == id;
    final ia = r['is_ai_generated'] == true;
    final bloqueado = _c.gerando;

    final corBorda = destaque || editando
        ? EstiloConversa.laranja
        : switch (marca) {
            MarcaRequisito.novo => const Color(0xFF2EBD5F),
            MarcaRequisito.alterado => EstiloConversa.laranja,
            null => Colors.white,
          };

    final estiloTitulo = EstiloConversa.fonte(
      tamanho: 14,
      peso: FontWeight.w600,
      cor: removido ? EstiloConversa.textoSecundario : EstiloConversa.texto,
    ).copyWith(
      decoration: removido ? TextDecoration.lineThrough : null,
    );

    return Container(
      key: widget.chavesCards.putIfAbsent(id, GlobalKey.new),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: removido
            ? Colors.white.withOpacity(0.35)
            : Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: corBorda,
            width: destaque || editando || marca != null ? 1.5 : 1),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Etiqueta(
                    ControladorConversa.ehFuncional(r)
                        ? 'Funcional'
                        : 'Não funcional',
                    cor: EstiloConversa.azulEscuro,
                  ),
                  const SizedBox(width: 6),
                  _Etiqueta('${r['prioridade']}', cor: _corPrioridade(r)),
                  const SizedBox(width: 6),
                  _Etiqueta(ia ? 'IA' : 'Manual',
                      cor: ia
                          ? EstiloConversa.laranja
                          : EstiloConversa.textoSecundario,
                      icone: ia ? Icons.auto_awesome : null),
                  if (removido) ...[
                    const SizedBox(width: 6),
                    const _Etiqueta('Removido', cor: Colors.red),
                  ] else if (marca != null) ...[
                    const SizedBox(width: 6),
                    _Etiqueta(
                      marca == MarcaRequisito.novo ? 'Novo' : 'Alterado',
                      cor: marca == MarcaRequisito.novo
                          ? const Color(0xFF2EBD5F)
                          : EstiloConversa.laranja,
                    ),
                  ],
                  const Spacer(),
                  if (!removido) ...[
                    _BotaoAprovar(
                      aprovado: aprovado,
                      onTap: bloqueado ? null : () => _c.alternarAprovacao(id),
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      visualDensity: VisualDensity.compact,
                      onPressed:
                          bloqueado ? null : () => _c.editarRequisito(id),
                      icon: const Icon(Icons.edit,
                          size: 17, color: EstiloConversa.texto),
                    ),
                    IconButton(
                      tooltip: 'Excluir',
                      visualDensity: VisualDensity.compact,
                      onPressed: bloqueado ? null : () => _excluir(r),
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: Colors.red.shade400),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: removido
                    ? null
                    : () => setState(
                        () => aberto ? _abertos.remove(id) : _abertos.add(id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: Text('${r['titulo']}', style: estiloTitulo)),
                      if (!removido)
                        Icon(aberto ? Icons.expand_less : Icons.expand_more,
                            size: 18, color: EstiloConversa.textoSecundario),
                    ],
                  ),
                ),
              ),
              if (aberto) ...[
                const SizedBox(height: 6),
                // A IA já devolve a descrição com categoria, ator principal,
                // pré e pós-condições, critérios de aceite, dependências e
                // riscos.
                Text('${r['descricao']}',
                    style: EstiloConversa.fonte(tamanho: 13, altura: 1.4)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _corPrioridade(Map r) =>
      switch ('${r['prioridade']}'.toLowerCase()) {
        'alta' => const Color(0xFFD62A1E),
        'baixa' => const Color(0xFF2E8B57),
        _ => const Color(0xFFB7791F),
      };
}

/// Card em modo de edição: título, descrição, tipo e prioridade editados
/// direto no bloco.
class _EditorRequisito extends StatefulWidget {
  const _EditorRequisito({
    super.key,
    required this.controlador,
    required this.requisito,
  });

  final ControladorConversa controlador;

  /// `null` para um requisito novo.
  final Map<String, dynamic>? requisito;

  @override
  State<_EditorRequisito> createState() => _EditorRequisitoState();
}

class _EditorRequisitoState extends State<_EditorRequisito> {
  late final _titulo = TextEditingController(
      text: widget.requisito?['titulo']?.toString() ??
          widget.controlador.tituloRascunho);
  late final _descricao = TextEditingController(
      text: widget.requisito?['descricao']?.toString() ?? '');
  final _focoTitulo = FocusNode();
  final _focoDescricao = FocusNode();
  late String _tipo;
  late String _prioridade;
  String? _erro;

  bool get _novo => widget.requisito == null;

  @override
  void initState() {
    super.initState();
    final r = widget.requisito;
    _tipo = r == null || ControladorConversa.ehFuncional(r)
        ? opcoesTipoRequisito.first
        : opcoesTipoRequisito.last;
    String semAcento(String s) =>
        s.toLowerCase().replaceAll('é', 'e').replaceAll('á', 'a');
    final prioridade = '${r?['prioridade'] ?? 'Média'}';
    _prioridade = opcoesPrioridade.firstWhere(
        (o) => semAcento(o) == semAcento(prioridade),
        orElse: () => 'Média');
    // Novo com título já digitado na barra: o foco vai para a descrição.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_titulo.text.isEmpty ? _focoTitulo : _focoDescricao).requestFocus();
    });
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    _focoTitulo.dispose();
    _focoDescricao.dispose();
    super.dispose();
  }

  void _salvar() {
    final erro = widget.controlador.salvarRequisitoManual(
      titulo: _titulo.text,
      descricao: _descricao.text,
      tipo: _tipo,
      prioridade: _prioridade,
    );
    if (erro != null) setState(() => _erro = erro);
  }

  InputDecoration _decoracao(String dica) {
    OutlineInputBorder borda(Color cor) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cor),
        );
    return InputDecoration(
      hintText: dica,
      hintStyle: EstiloConversa.fonte(
          tamanho: 14, cor: EstiloConversa.textoSecundario.withOpacity(0.7)),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: borda(EstiloConversa.azulEscuro.withOpacity(0.12)),
      enabledBorder: borda(EstiloConversa.azulEscuro.withOpacity(0.12)),
      focusedBorder: borda(EstiloConversa.azulEscuro),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EstiloConversa.azulEscuro, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_novo ? 'NOVO REQUISITO' : 'EDITANDO REQUISITO',
              style: EstiloConversa.fonte(
                      tamanho: 10.5,
                      peso: FontWeight.w600,
                      cor: EstiloConversa.textoSecundario)
                  .copyWith(letterSpacing: 0.6)),
          const SizedBox(height: 8),
          TextField(
            controller: _titulo,
            focusNode: _focoTitulo,
            style: EstiloConversa.fonte(tamanho: 14, peso: FontWeight.w600),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _focoDescricao.requestFocus(),
            decoration: _decoracao('Título do requisito'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descricao,
            focusNode: _focoDescricao,
            minLines: 3,
            maxLines: 8,
            style: EstiloConversa.fonte(tamanho: 13.5, altura: 1.4),
            decoration: _decoracao('Descrição do requisito'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Escolhas(
                opcoes: opcoesTipoRequisito,
                valor: _tipo,
                aoMudar: (v) => setState(() => _tipo = v),
              ),
              _Escolhas(
                opcoes: opcoesPrioridade,
                valor: _prioridade,
                aoMudar: (v) => setState(() => _prioridade = v),
              ),
            ],
          ),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(_erro!,
                style: EstiloConversa.fonte(
                    tamanho: 12, cor: Colors.red.shade700)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.controlador.cancelarEdicaoRequisito,
                style: TextButton.styleFrom(
                    foregroundColor: EstiloConversa.textoSecundario),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _salvar,
                style: FilledButton.styleFrom(
                  backgroundColor: EstiloConversa.azulEscuro,
                  shape: const StadiumBorder(),
                ),
                child: Text(_novo ? 'Adicionar' : 'Salvar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chips de escolha única (tipo e prioridade do requisito).
class _Escolhas extends StatelessWidget {
  const _Escolhas({
    required this.opcoes,
    required this.valor,
    required this.aoMudar,
  });

  final List<String> opcoes;
  final String valor;
  final ValueChanged<String> aoMudar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (final o in opcoes)
          ChoiceChip(
            label: Text(o),
            selected: o == valor,
            onSelected: (_) => aoMudar(o),
            showCheckmark: false,
            labelStyle: EstiloConversa.fonte(
                tamanho: 12.5,
                cor: o == valor ? Colors.white : EstiloConversa.texto),
            selectedColor: EstiloConversa.azulEscuro,
            backgroundColor: Colors.white,
            side: BorderSide(
                color: o == valor
                    ? EstiloConversa.azulEscuro
                    : EstiloConversa.azulEscuro.withOpacity(0.15)),
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador(this.rotulo, this.valor, {this.destaque = false});
  final String rotulo;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: destaque
            ? const Color(0xFF2EBD5F).withOpacity(0.15)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$rotulo $valor',
          style: EstiloConversa.fonte(
              tamanho: 12,
              peso: FontWeight.w500,
              cor: destaque ? const Color(0xFF1E7B40) : EstiloConversa.texto)),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, {required this.cor, this.icone});
  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 11, color: cor),
            const SizedBox(width: 3),
          ],
          Text(texto,
              style: EstiloConversa.fonte(
                  tamanho: 11, peso: FontWeight.w600, cor: cor)),
        ],
      ),
    );
  }
}

class _BotaoAprovar extends StatelessWidget {
  const _BotaoAprovar({required this.aprovado, required this.onTap});
  final bool aprovado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF2EBD5F);
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: aprovado ? Colors.white : verde,
        backgroundColor: aprovado ? verde : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 28),
        shape: StadiumBorder(side: BorderSide(color: verde.withOpacity(0.8))),
        textStyle: EstiloConversa.fonte(tamanho: 12, peso: FontWeight.w600),
      ),
      icon: Icon(aprovado ? Icons.check_circle : Icons.check, size: 15),
      label: Text(aprovado ? 'Aprovado' : 'Aprovar'),
    );
  }
}

class _AcaoBloco extends StatelessWidget {
  const _AcaoBloco(this.texto, this.icone, this.onTap);
  final String texto;
  final IconData icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: EstiloConversa.laranja,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        textStyle: EstiloConversa.fonte(tamanho: 12.5, peso: FontWeight.w600),
      ),
      icon: Icon(icone, size: 16),
      label: Text(texto),
    );
  }
}

// =====================================================================
// Card do diagrama de casos de uso
// =====================================================================

/// Card do diagrama: atores, diagrama com zoom e arraste, tela cheia,
/// Gerar novamente e a versão anterior com Restaurar.
class CardDiagrama extends StatefulWidget {
  const CardDiagrama({
    super.key,
    required this.controlador,
    this.alturaDiagrama = 260,
  });

  final ControladorConversa controlador;
  final double alturaDiagrama;

  @override
  State<CardDiagrama> createState() => _CardDiagramaState();
}

class _CardDiagramaState extends State<CardDiagrama> {
  final _transformacao = TransformationController();
  bool _verAnterior = false;

  ControladorConversa get _c => widget.controlador;

  @override
  void dispose() {
    _transformacao.dispose();
    super.dispose();
  }

  void _zoom(double fator) {
    final escala = (_transformacao.value.getMaxScaleOnAxis() * fator)
        .clamp(0.5, 4.0)
        .toDouble();
    _transformacao.value = Matrix4.identity()..scale(escala);
  }

  @override
  Widget build(BuildContext context) {
    final d = _c.diagrama;
    if (d == null) return const SizedBox.shrink();
    final anterior = _c.diagramaAnterior;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: EstiloConversa.balaoSistema,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined,
                  size: 18, color: EstiloConversa.texto),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Caso de uso · v${d.versao}',
                    style: EstiloConversa.fonte(peso: FontWeight.w600)),
              ),
              IconButton(
                tooltip: 'Diminuir zoom',
                visualDensity: VisualDensity.compact,
                onPressed: d.imagem == null ? null : () => _zoom(1 / 1.25),
                icon: const Icon(Icons.zoom_out, size: 18),
              ),
              IconButton(
                tooltip: 'Aumentar zoom',
                visualDensity: VisualDensity.compact,
                onPressed: d.imagem == null ? null : () => _zoom(1.25),
                icon: const Icon(Icons.zoom_in, size: 18),
              ),
              IconButton(
                tooltip: 'Tela cheia',
                visualDensity: VisualDensity.compact,
                onPressed: d.imagem == null
                    ? null
                    : () => verDiagramaTelaCheia(context, d),
                icon: const Icon(Icons.fullscreen, size: 20),
              ),
            ],
          ),
          if (_c.requisitosMudaram) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                color: EstiloConversa.laranja.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: EstiloConversa.laranja),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Os requisitos mudaram',
                        style: EstiloConversa.fonte(
                            tamanho: 13, peso: FontWeight.w500)),
                  ),
                  _AcaoBloco('Gerar novamente', Icons.refresh,
                      _c.gerando ? null : _c.gerarDiagrama),
                ],
              ),
            ),
          ],
          if (d.atores.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in d.atores)
                  Chip(
                    avatar: const Icon(Icons.person, size: 15),
                    label: Text(a, style: EstiloConversa.fonte(tamanho: 12)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.white.withOpacity(0.8),
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _imagem(d, widget.alturaDiagrama, interativo: true),
          if (anterior != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _verAnterior = !_verAnterior),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(_verAnterior ? Icons.expand_less : Icons.expand_more,
                        size: 18, color: EstiloConversa.textoSecundario),
                    const SizedBox(width: 4),
                    Text('Ver versão anterior',
                        style: EstiloConversa.fonte(
                            tamanho: 12.5,
                            peso: FontWeight.w500,
                            cor: EstiloConversa.textoSecundario)),
                  ],
                ),
              ),
            ),
            if (_verAnterior) ...[
              Opacity(opacity: 0.8, child: _imagem(anterior, 140)),
              Align(
                alignment: Alignment.centerRight,
                child: _AcaoBloco('Restaurar', Icons.restore,
                    _c.gerando ? null : _c.restaurarDiagramaAnterior),
              ),
            ],
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 2,
            children: [
              _AcaoBloco('Gerar novamente', Icons.refresh,
                  _c.gerando ? null : _c.gerarDiagrama),
            ],
          ),
          Text('Isto é só uma visualização, nada é salvo ainda.',
              style: EstiloConversa.fonte(
                  tamanho: 11, cor: EstiloConversa.textoSecundario)),
        ],
      ),
    );
  }

  Widget _imagem(Diagrama d, double altura, {bool interativo = false}) {
    if (d.imagem == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.aviso ?? 'Não foi possível renderizar a imagem do diagrama.',
            style:
                EstiloConversa.fonte(tamanho: 13, cor: EstiloConversa.laranja),
          ),
          if ((d.mermaid ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EstiloConversa.azulEscuro,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(d.mermaid!,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.white)),
            ),
          ],
        ],
      );
    }

    final imagem = Image.memory(d.imagem!, fit: BoxFit.contain);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: altura,
        width: double.infinity,
        color: Colors.white,
        // Arraste para mover; o zoom fica nos botões, para a roda do mouse
        // continuar rolando o chat.
        child: interativo
            ? InteractiveViewer(
                transformationController: _transformacao,
                scaleEnabled: false,
                minScale: 0.5,
                maxScale: 4,
                boundaryMargin: const EdgeInsets.all(200),
                child: Center(child: imagem),
              )
            : imagem,
      ),
    );
  }
}

/// Diagrama em tela cheia, com zoom (inclusive pela roda do mouse).
void verDiagramaTelaCheia(BuildContext context, Diagrama d) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text('Caso de uso · v${d.versao}',
                    style: EstiloConversa.fonte(
                        tamanho: 16, peso: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Center(child: Image.memory(d.imagem!)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
