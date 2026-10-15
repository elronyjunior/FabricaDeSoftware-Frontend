import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'controlador_conversa.dart';
import 'estilo_conversa.dart';
import 'perguntas.dart';

/// Único lugar onde o usuário responde. Muda de forma conforme o modo da
/// pergunta ativa e devolve o valor para o [ControladorConversa].
class BarraResposta extends StatefulWidget {
  const BarraResposta({
    super.key,
    required this.controlador,
    this.alturaMaxima,
    this.onProximaEtapa,
  });

  final ControladorConversa controlador;

  /// "Próxima etapa" ao lado do enviar (requisitos e diagrama), no mesmo
  /// estilo do "Pular". `null` esconde.
  final VoidCallback? onProximaEtapa;

  /// Altura máxima da área acima do campo (≈ 40% do modal).
  final double? alturaMaxima;

  @override
  State<BarraResposta> createState() => _BarraRespostaState();
}

class _BarraRespostaState extends State<BarraResposta> {
  final _texto = TextEditingController();
  final _foco = FocusNode();

  List<Map<String, dynamic>> _selecao = [];
  String? _erro;
  int? _ultimaPergunta;
  int? _ultimaEdicao;

  ControladorConversa get _c => widget.controlador;
  Pergunta? get _p => _c.perguntaAtiva;

  @override
  void initState() {
    super.initState();
    _c.addListener(_aoMudarConversa);
    _texto.addListener(() => setState(() {}));
    _prepararPergunta();
  }

  @override
  void dispose() {
    _c.removeListener(_aoMudarConversa);
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _aoMudarConversa() {
    if (_c.indiceAtivo != _ultimaPergunta || _c.editando != _ultimaEdicao) {
      _prepararPergunta();
    }
    final sugestao = _c.consumirTextoParaBarra();
    if (sugestao != null) {
      _texto.text = sugestao;
      _foco.requestFocus();
    }
    if (mounted) setState(() {});
  }

  /// Ao trocar de pergunta: limpa (ou preenche, na edição) e devolve o foco.
  void _prepararPergunta() {
    _ultimaPergunta = _c.indiceAtivo;
    _ultimaEdicao = _c.editando;
    _erro = null;
    _selecao = [];
    _texto.clear();

    final p = _p;
    if (p != null &&
        _c.respondida(_c.indiceAtivo) &&
        !_c.pulada(_c.indiceAtivo)) {
      final v = _c.valor(p.campo);
      switch (p.modo) {
        case ModoResposta.multipla:
          _selecao = [
            for (final m in (v as List)) Map<String, dynamic>.from(m)
          ];
        case ModoResposta.texto:
        case ModoResposta.textoLongo:
          _texto.text = (v as String?) ?? '';
        case ModoResposta.data:
          if (v != null) {
            _texto.text = DateFormat('dd/MM/yyyy').format(v as DateTime);
          }
        case ModoResposta.numero:
          if (v != null) {
            _texto.text = ControladorConversa.formatarNumero(v as double);
          }
        default:
          break;
      }
    }

    _focar();
  }

  /// Devolve o foco à barra. Solta e pega de novo: no navegador, depois de
  /// um envio com Enter a conexão de texto antiga não recebe mais o que é
  /// digitado.
  void _focar() {
    _foco.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _p != null) _foco.requestFocus();
    });
  }

  // ---------------------------------------------------------------------
  // Envio
  // ---------------------------------------------------------------------

  bool get _bloqueado => _p == null || _c.gerando || _c.enviando;

  /// "Pular" aparece nas perguntas opcionais enquanto nada foi respondido.
  bool get _podePular {
    final p = _p;
    return p != null &&
        !p.obrigatorio &&
        _c.editando == null &&
        _c.estadoIA != EstadoIA.ativo &&
        p.modo != ModoResposta.diagrama &&
        _texto.text.isEmpty &&
        _selecao.isEmpty;
  }

  void _enviar() {
    final p = _p;
    if (p == null || _bloqueado) return;
    final texto = _texto.text.trim();

    if (_c.estadoIA == EstadoIA.ativo) {
      final String? vazio = texto.isNotEmpty
          ? null
          : switch (p.modo) {
              ModoResposta.requisitos ||
              ModoResposta.diagrama =>
                'Escreva um comando para a IA.',
              _ when p.campo == 'escopo' =>
                'Descreva o escopo para a IA gerar os requisitos.',
              _ => null,
            };
      if (vazio != null) {
        setState(() => _erro = vazio);
        return;
      }
      _c.pedirIA(texto);
      _texto.clear();
      setState(() => _erro = null);
      return;
    }

    String? erro;
    switch (p.modo) {
      case ModoResposta.texto:
      case ModoResposta.textoLongo:
        erro = _c.responder(texto);

      case ModoResposta.escolha:
        final opcao = _opcoesFiltradas().where(
            (o) => o['nome'].toString().toLowerCase() == texto.toLowerCase());
        if (opcao.isNotEmpty) {
          erro = _c.responder(opcao.first['id']);
        } else if (texto.isEmpty && !p.obrigatorio) {
          _c.pular();
        } else {
          erro = 'Escolha uma das opções.';
        }

      case ModoResposta.busca:
        final resultados = _opcoesFiltradas();
        if (texto.isNotEmpty && resultados.length == 1) {
          erro = _c.responder(resultados.first);
        } else {
          erro = 'Selecione uma opção da lista.';
        }

      case ModoResposta.multipla:
        if (_selecao.isEmpty && !p.obrigatorio) {
          _c.pular();
        } else {
          erro = _c.responder(_selecao);
        }

      case ModoResposta.requisitos:
        // IA desligada: o título vira um card novo no bloco, aberto para
        // completar a descrição, o tipo e a prioridade ali mesmo.
        _c.novoRequisito(texto);
        _texto.clear();

      case ModoResposta.data:
        final data = _lerData(texto);
        erro = data == null && texto.isNotEmpty
            ? 'Use o formato dd/mm/aaaa.'
            : _c.responder(data);

      case ModoResposta.numero:
        final numero = _lerNumero(texto);
        erro = numero == null && texto.isNotEmpty
            ? 'Informe um valor válido.'
            : _c.responder(numero);

      case ModoResposta.diagrama:
        // A IA fica sempre ativa nesta etapa (tratado acima).
        break;
    }

    setState(() => _erro = erro);
  }

  DateTime? _lerData(String texto) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(texto);
    } catch (_) {
      return null;
    }
  }

  double? _lerNumero(String texto) {
    // Máscara: ponto separa milhar e vírgula separa os centavos.
    final t = texto.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _abrirCalendario() async {
    final atual = _lerData(_texto.text.trim()) ?? DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (data == null) return;
    _texto.text = DateFormat('dd/MM/yyyy').format(data);
    _enviar();
  }

  List<Map<String, dynamic>> _opcoesFiltradas() {
    final filtro = _texto.text.trim().toLowerCase();
    final opcoes = _c.opcoes(_p?.fonte);
    if (filtro.isEmpty) return opcoes;
    return [
      for (final o in opcoes)
        if (_nomeOpcao(o).toLowerCase().contains(filtro)) o
    ];
  }

  static String _nomeOpcao(Map<String, dynamic> o) =>
      (o['nome'] ?? o['razao_social'] ?? '').toString();

  bool _selecionado(Map<String, dynamic> o) =>
      _selecao.any((s) => s['id'] == o['id']);

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final topo = _conteudoTopo();
    final ia = _c.estadoIA == EstadoIA.ativo || _c.estadoIA == EstadoIA.gerando;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: _MolduraBarra(
        ia: ia,
        focado: _foco.hasFocus,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (topo != null)
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: widget.alturaMaxima ?? 240),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
                  child: topo,
                ),
              ),
            // Com chave: quando a área de cima aparece ou some, o campo
            // continua o mesmo (sem perder o foco nem o Enter).
            KeyedSubtree(
                key: const ValueKey('linha-entrada'), child: _linhaEntrada()),
          ],
        ),
      ),
    );
  }

  Widget _linhaEntrada() {
    final p = _p;
    final ia = _c.estadoIA;
    // O escopo é texto longo mesmo com a IA ativa.
    final longo = p?.modo == ModoResposta.textoLongo &&
        (ia != EstadoIA.ativo || p?.campo == 'escopo');
    final somenteLeitura = p == null ||
        p.modo == ModoResposta.escolha && _c.opcoes(p.fonte).length <= 8;

    String dica;
    if (p == null) {
      dica = 'Revise o resumo e crie o projeto';
    } else if (ia == EstadoIA.ativo || ia == EstadoIA.gerando) {
      dica =
          p.dicaIA ?? 'Peça para a IA (ex.: "API que mostra clima por cidade")';
    } else if (somenteLeitura) {
      dica = 'Toque em uma opção acima';
    } else {
      dica = p.dica;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: EstiloConversa.alturaBarra),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BotaoIA(controlador: _c),
          Expanded(
            child: TextField(
              controller: _texto,
              focusNode: _foco,
              enabled: !_bloqueado,
              readOnly: somenteLeitura,
              minLines: 1,
              maxLines: longo ? 5 : 1,
              keyboardType:
                  longo ? TextInputType.multiline : TextInputType.text,
              // Enter envia; o foco continua na barra para a próxima pergunta.
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviar(),
              onEditingComplete: () {},
              // Máscaras (só quando o texto é a resposta, não um pedido
              // para a IA).
              inputFormatters: switch (p?.modo) {
                _ when ia == EstadoIA.ativo => const [],
                ModoResposta.data => [_MascaraData()],
                ModoResposta.numero => [_MascaraNumero()],
                _ => const [],
              },
              textAlignVertical: TextAlignVertical.center,
              cursorColor: EstiloConversa.azulEscuro,
              cursorWidth: 1.2,
              cursorHeight: 22,
              style: EstiloConversa.fonte(),
              decoration: InputDecoration.collapsed(
                hintText: dica,
                hintStyle: EstiloConversa.fonte(
                    cor: EstiloConversa.textoSecundario.withOpacity(0.7)),
              ).copyWith(
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (p?.modo == ModoResposta.data)
            IconButton(
              tooltip: 'Abrir calendário',
              onPressed: _bloqueado ? null : _abrirCalendario,
              icon: const Icon(Icons.calendar_month,
                  size: 20, color: EstiloConversa.azulEscuro),
            ),
          if (_podePular) _Acao('Pular', onTap: _c.pular),
          if (widget.onProximaEtapa != null)
            _Acao('Próxima etapa →',
                onTap: _c.gerando ? null : widget.onProximaEtapa),
          const SizedBox(width: 6),
          _BotaoEnviar(
            habilitado: !_bloqueado,
            carregando: _c.gerando,
            onPressed: _enviar,
          ),
          const SizedBox(width: 3),
        ],
      ),
    );
  }

  /// Rótulo, opções e ações que aparecem acima do campo.
  Widget? _conteudoTopo() {
    final p = _p;
    if (p == null) return null;
    final ia = _c.estadoIA == EstadoIA.ativo || _c.estadoIA == EstadoIA.gerando;

    final partes = <Widget>[];

    // Rótulo + Editando/Cancelar. Com a IA ativa não há rótulo: a borda e o
    // ícone laranja já mostram que o texto vai para a IA.
    final String? rotulo = ia ? null : p.rotulo;
    final editando = _c.editando != null;

    if (rotulo != null || editando) {
      partes.add(Row(
        children: [
          if (editando)
            _Etiqueta('Editando resposta', cor: EstiloConversa.laranja),
          if (editando && rotulo != null) const SizedBox(width: 10),
          if (rotulo != null) Expanded(child: _Etiqueta(rotulo)),
          if (rotulo == null) const Spacer(),
          if (editando) _Acao('Cancelar', onTap: _c.cancelarEdicao),
        ],
      ));
    }

    if (!ia && _c.estadoIA != EstadoIA.gerando) {
      final opcoes = _opcoesDoModo(p);
      if (opcoes != null) partes.add(opcoes);
    }

    if (_erro != null) {
      partes.add(Text(_erro!,
          style: EstiloConversa.fonte(tamanho: 12, cor: Colors.red.shade700)));
    }

    if (partes.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < partes.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          partes[i],
        ],
      ],
    );
  }

  Widget? _opcoesDoModo(Pergunta p) {
    switch (p.modo) {
      case ModoResposta.texto:
        if (p.sugestoes.isEmpty || _texto.text.isNotEmpty) return null;
        return _Chips([
          for (final s in p.sugestoes)
            _Chip(s, onTap: () {
              _texto.text = s;
              _enviar();
            }),
        ]);

      case ModoResposta.escolha:
        return _Chips([
          for (final o in _opcoesFiltradas())
            _Chip(_nomeOpcao(o),
                marcado: _c.valor(p.campo) == o['id'],
                onTap: () => setState(() => _erro = _c.responder(o['id']))),
        ]);

      case ModoResposta.busca:
        if (_c.carregandoOpcoes) return const _Carregando();
        final resultados = _opcoesFiltradas().take(5).toList();
        if (resultados.isEmpty) {
          return Text('Nenhum resultado.',
              style: EstiloConversa.fonte(
                  tamanho: 13, cor: EstiloConversa.textoSecundario));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final o in resultados)
              _ItemBusca(_nomeOpcao(o),
                  onTap: () => setState(() => _erro = _c.responder(o))),
          ],
        );

      case ModoResposta.multipla:
        if (_c.carregandoOpcoes) return const _Carregando();
        final opcoes = _opcoesFiltradas();
        if (opcoes.isEmpty) {
          return Text('Nenhuma opção encontrada.',
              style: EstiloConversa.fonte(
                  tamanho: 13, cor: EstiloConversa.textoSecundario));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Chips([
              for (final o in opcoes)
                _Chip(_nomeOpcao(o),
                    marcado: _selecionado(o),
                    onTap: () => setState(() {
                          _erro = null;
                          _selecionado(o)
                              ? _selecao.removeWhere((s) => s['id'] == o['id'])
                              : _selecao.add(o);
                        })),
            ]),
            const SizedBox(height: 6),
            Text(
              _selecao.isEmpty
                  ? 'Nenhuma selecionada · envie para confirmar'
                  : '${_selecao.length} selecionada(s) · envie para confirmar',
              style: EstiloConversa.fonte(
                  tamanho: 11, cor: EstiloConversa.textoSecundario),
            ),
          ],
        );

      case ModoResposta.requisitos:
      case ModoResposta.diagrama:
        return null;

      case ModoResposta.data:
      case ModoResposta.numero:
      case ModoResposta.textoLongo:
        return null;
    }
  }
}

// =====================================================================
// Peças da barra
// =====================================================================

class _BotaoIA extends StatefulWidget {
  const _BotaoIA({required this.controlador});
  final ControladorConversa controlador;

  @override
  State<_BotaoIA> createState() => _BotaoIAState();
}

class _BotaoIAState extends State<_BotaoIA>
    with SingleTickerProviderStateMixin {
  // Pulso contínuo do ícone enquanto a IA está ativa.
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.controlador.estadoIA;
    final ativo = estado == EstadoIA.ativo || estado == EstadoIA.gerando;
    final desabilitado = estado == EstadoIA.desabilitado;
    if (ativo && !_pulso.isAnimating) {
      _pulso.repeat(reverse: true);
    } else if (!ativo && _pulso.isAnimating) {
      _pulso.stop();
      _pulso.value = 0;
    }

    final dica = switch (estado) {
      EstadoIA.desabilitado => 'IA não disponível nesta pergunta',
      EstadoIA.disponivel => 'Ativar a IA',
      EstadoIA.ativo => 'IA ativa: o texto enviado vai para a IA',
      EstadoIA.gerando => 'A IA está gerando...',
    };

    return Tooltip(
      message: dica,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 6),
        child: InkResponse(
          onTap: desabilitado ? null : widget.controlador.alternarIA,
          radius: 18,
          child: SizedBox.square(
            dimension: 30,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulso,
                builder: (context, filho) {
                  final t = Curves.easeInOut.transform(_pulso.value);
                  return Transform.scale(scale: 1 + 0.14 * t, child: filho);
                },
                child: Icon(
                  Icons.auto_awesome,
                  size: 21,
                  color: ativo
                      ? EstiloConversa.laranja
                      : desabilitado
                          ? EstiloConversa.desabilitado.withOpacity(0.6)
                          : EstiloConversa.textoSecundario,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contorno da barra. Sem IA: borda discreta (mais escura com foco).
/// Com IA: borda laranja com um brilho que percorre o contorno e um halo
/// pulsando, para ficar claro o tempo todo que o texto vai para a IA.
class _MolduraBarra extends StatefulWidget {
  const _MolduraBarra({
    required this.ia,
    required this.focado,
    required this.child,
  });

  final bool ia;
  final bool focado;
  final Widget child;

  @override
  State<_MolduraBarra> createState() => _MolduraBarraState();
}

class _MolduraBarraState extends State<_MolduraBarra>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.ia) _giro.repeat();
  }

  @override
  void didUpdateWidget(_MolduraBarra antigo) {
    super.didUpdateWidget(antigo);
    if (widget.ia && !_giro.isAnimating) _giro.repeat();
    if (!widget.ia && _giro.isAnimating) _giro.stop();
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const raio = EstiloConversa.alturaBarra / 2;
    final semIA = Container(
      decoration: BoxDecoration(
        color: EstiloConversa.fundoBarra,
        borderRadius: BorderRadius.circular(raio),
        border: Border.all(
          color: EstiloConversa.azulEscuro
              .withOpacity(widget.focado ? 0.45 : 0.18),
        ),
      ),
      child: widget.child,
    );
    if (!widget.ia) return semIA;

    return AnimatedBuilder(
      animation: _giro,
      builder: (context, filho) {
        final t = _giro.value;
        // Halo: respira duas vezes por volta do brilho.
        final halo = 0.5 + 0.5 * math.sin(t * 4 * math.pi);
        return CustomPaint(
          foregroundPainter: _BordaIA(progresso: t, raio: raio),
          child: Container(
            decoration: BoxDecoration(
              color: Color.lerp(EstiloConversa.fundoBarra, Colors.white, 0.35),
              borderRadius: BorderRadius.circular(raio),
              boxShadow: [
                BoxShadow(
                  color: EstiloConversa.laranja.withOpacity(0.18 + 0.17 * halo),
                  blurRadius: 10 + 8 * halo,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: filho,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _BordaIA extends CustomPainter {
  _BordaIA({required this.progresso, required this.raio});

  final double progresso;
  final double raio;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect.deflate(0.75), Radius.circular(raio));
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = SweepGradient(
        colors: const [
          EstiloConversa.laranja,
          Color(0xFFFFB27A),
          Color(0xFFFFF1E6),
          Color(0xFFFFB27A),
          EstiloConversa.laranja,
          EstiloConversa.laranja,
        ],
        stops: const [0.0, 0.08, 0.14, 0.2, 0.3, 1.0],
        transform: GradientRotation(progresso * 2 * math.pi),
      ).createShader(rect);
    canvas.drawRRect(rrect, pincel);
  }

  @override
  bool shouldRepaint(_BordaIA antigo) => antigo.progresso != progresso;
}

class _BotaoEnviar extends StatelessWidget {
  const _BotaoEnviar({
    required this.habilitado,
    required this.carregando,
    required this.onPressed,
  });

  final bool habilitado;
  final bool carregando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: habilitado
          ? EstiloConversa.azulEscuro
          : EstiloConversa.azulEscuro.withOpacity(0.4),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: habilitado ? onPressed : null,
        child: SizedBox(
          width: 44,
          height: 34,
          child: Center(
            child: carregando
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, {this.cor = EstiloConversa.textoSecundario});
  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Text(
        texto.toUpperCase(),
        overflow: TextOverflow.ellipsis,
        style:
            EstiloConversa.fonte(tamanho: 10.5, peso: FontWeight.w600, cor: cor)
                .copyWith(letterSpacing: 0.6),
      );
}

class _Acao extends StatelessWidget {
  const _Acao(this.texto, {required this.onTap});
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(texto,
              style: EstiloConversa.fonte(
                  tamanho: 12,
                  peso: FontWeight.w600,
                  cor: onTap == null
                      ? EstiloConversa.desabilitado
                      : EstiloConversa.laranja)),
        ),
      );
}

class _Chips extends StatelessWidget {
  const _Chips(this.chips);
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: chips);
}

class _Chip extends StatelessWidget {
  const _Chip(this.texto, {this.marcado = false, this.onTap});

  final String texto;
  final bool marcado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cor = marcado ? Colors.white : EstiloConversa.texto;
    return Material(
      color:
          marcado ? EstiloConversa.azulEscuro : Colors.white.withOpacity(0.7),
      shape: StadiumBorder(
        side: BorderSide(
            color: marcado
                ? EstiloConversa.azulEscuro
                : EstiloConversa.azulEscuro.withOpacity(0.15)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(texto,
                    overflow: TextOverflow.ellipsis,
                    style: EstiloConversa.fonte(tamanho: 13, cor: cor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemBusca extends StatelessWidget {
  const _ItemBusca(this.texto, {required this.onTap});
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.business,
                  size: 16, color: EstiloConversa.textoSecundario),
              const SizedBox(width: 10),
              Expanded(
                child: Text(texto,
                    overflow: TextOverflow.ellipsis,
                    style: EstiloConversa.fonte(tamanho: 14)),
              ),
            ],
          ),
        ),
      );
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: EstiloConversa.laranja),
        ),
      );
}

// =====================================================================
// Máscaras
// =====================================================================

/// dd/mm/aaaa enquanto digita: "20102026" vira "20/10/2026".
class _MascaraData extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue antigo, TextEditingValue novo) {
    final digitos = novo.text.replaceAll(RegExp(r'[^0-9]'), '');
    final d = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
    final saida = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 4) saida.write('/');
      saida.write(d[i]);
    }
    final texto = saida.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Valor com separador de milhar: "100000" vira "100.000"; a vírgula
/// abre os centavos (até 2 casas): "1234,5" vira "1.234,5".
class _MascaraNumero extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue antigo, TextEditingValue novo) {
    final limpo = novo.text.replaceAll(RegExp(r'[^0-9,]'), '');
    final virgula = limpo.indexOf(',');
    var inteiro = virgula < 0 ? limpo : limpo.substring(0, virgula);
    final centavos =
        virgula < 0 ? null : limpo.substring(virgula + 1).replaceAll(',', '');

    inteiro = inteiro.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final grupos = <String>[];
    for (var fim = inteiro.length; fim > 0; fim -= 3) {
      grupos.insert(0, inteiro.substring(fim - 3 < 0 ? 0 : fim - 3, fim));
    }
    var texto = grupos.join('.');
    if (centavos != null) {
      texto = '${texto.isEmpty ? '0' : texto},'
          '${centavos.length > 2 ? centavos.substring(0, 2) : centavos}';
    }
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
