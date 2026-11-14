import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Mensagem de exibição do chat - só cosmética. A memória de verdade da
// conversa vive no backend (sessionId + chatSessionStore.js); esta lista é
// reconstruída do zero a cada vez que o passo do wizard é montado.
class ChatMensagem {
  final String texto;
  final bool deUsuario; // true = usuário, false = IA

  ChatMensagem({required this.texto, required this.deUsuario});
}

// Painel de chat reaproveitado pelos passos de Requisitos e Diagrama - só
// cuida da exibição (bolhas + campo de envio). Cada passo mantém sua própria
// lista de ChatMensagem e seu próprio sessionId, e decide o que fazer com a
// resposta (atualizar a lista de requisitos, atualizar o diagrama...) - este
// widget não sabe nada sobre esses domínios.
class ChatIAPanel extends StatefulWidget {
  final List<ChatMensagem> mensagens;
  final bool isLoading;
  final String placeholder;
  final ValueChanged<String> onEnviar;
  // Quando não-nulo, desabilita o envio e mostra este texto no lugar do
  // placeholder (ex: "Gere um diagrama primeiro para poder conversar").
  final String? avisoDesabilitado;
  // Quando não-nulo, mostra um X no cabeçalho (painel filho do modal).
  final VoidCallback? aoFechar;
  final double raio;

  /// Frase curta abaixo do título (o que o assistente faz nesta aba).
  final String subtitulo;

  /// Pedidos prontos mostrados na conversa vazia; tocar envia o pedido.
  final List<String> sugestoes;

  const ChatIAPanel({
    super.key,
    required this.mensagens,
    required this.isLoading,
    required this.onEnviar,
    this.placeholder = 'Escreva uma mensagem...',
    this.avisoDesabilitado,
    this.aoFechar,
    this.raio = 14,
    this.subtitulo = 'Converse para ajustar o projeto.',
    this.sugestoes = const [],
  });

  @override
  State<ChatIAPanel> createState() => _ChatIAPanelState();
}

class _ChatIAPanelState extends State<ChatIAPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool get _desabilitado => widget.avisoDesabilitado != null;

  @override
  void didUpdateWidget(covariant ChatIAPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mensagens.length != oldWidget.mensagens.length ||
        widget.isLoading != oldWidget.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollParaFinal());
    }
  }

  void _scrollParaFinal() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _enviar([String? pronto]) {
    final texto = (pronto ?? _controller.text).trim();
    if (texto.isEmpty || widget.isLoading || _desabilitado) return;
    _controller.clear();
    widget.onEnviar(texto);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.raio),
        border:
            widget.aoFechar == null ? Border.all(color: CoresIdv.borda) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _cabecalho(),
          const Divider(height: 1, color: CoresIdv.borda),
          Expanded(
            child: ColoredBox(
              color: CoresIdv.campo,
              child: widget.mensagens.isEmpty && !widget.isLoading
                  ? _conversaVazia()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      itemCount:
                          widget.mensagens.length + (widget.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == widget.mensagens.length) {
                          return _bolhaDigitando();
                        }
                        return _bolha(widget.mensagens[index]);
                      },
                    ),
            ),
          ),
          const Divider(height: 1, color: CoresIdv.borda),
          _campoEnvio(),
        ],
      ),
    );
  }

  Widget _iconeIa({double tamanho = 40}) => Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: CoresIdv.azul,
          borderRadius: BorderRadius.circular(tamanho * 0.3),
        ),
        alignment: Alignment.center,
        child: Icon(FontAwesomeIcons.wandMagicSparkles,
            size: tamanho * 0.4, color: StyleProjetos.laranjaClaro),
      );

  Widget _cabecalho() {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(20, 18, widget.aoFechar != null ? 12 : 20, 16),
      child: Row(
        children: [
          _iconeIa(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistente IA',
                    style: fonteIdv(tamanho: 17, peso: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(widget.subtitulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        fonteIdv(tamanho: 13, cor: CoresIdv.textoSecundario)),
              ],
            ),
          ),
          if (widget.aoFechar != null)
            IconButton(
              tooltip: 'Fechar assistente',
              onPressed: widget.aoFechar,
              icon: const Icon(Icons.close_rounded,
                  color: CoresIdv.textoSecundario),
            ),
        ],
      ),
    );
  }

  Widget _conversaVazia() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          _iconeIa(tamanho: 56),
          const SizedBox(height: 16),
          Text('Como posso ajudar?',
              textAlign: TextAlign.center,
              style: fonteIdv(tamanho: 18, peso: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            widget.avisoDesabilitado ??
                'Peça o que quiser ajustar e eu atualizo para você.',
            textAlign: TextAlign.center,
            style: fonteIdv(
                tamanho: 14, cor: CoresIdv.textoSecundario, altura: 1.5),
          ),
          if (widget.sugestoes.isNotEmpty && !_desabilitado) ...[
            const SizedBox(height: 24),
            for (final sugestao in widget.sugestoes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Sugestao(
                    texto: sugestao, aoTocar: () => _enviar(sugestao)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _bolha(ChatMensagem msg) {
    final doUsuario = msg.deUsuario;
    const raio = Radius.circular(16);
    const ponta = Radius.circular(4);

    final bolha = Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: doUsuario ? CoresIdv.azul : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: raio,
            topRight: raio,
            bottomLeft: doUsuario ? raio : ponta,
            bottomRight: doUsuario ? ponta : raio,
          ),
          border: doUsuario ? null : Border.all(color: CoresIdv.borda),
        ),
        child: SelectableText(
          msg.texto,
          style: fonteIdv(
              tamanho: 14,
              cor: doUsuario ? Colors.white : CoresIdv.texto,
              altura: 1.5),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            doUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: doUsuario
            ? [const SizedBox(width: 48), bolha]
            : [
                _iconeIa(tamanho: 28),
                const SizedBox(width: 8),
                bolha,
                const SizedBox(width: 48),
              ],
      ),
    );
  }

  Widget _bolhaDigitando() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _iconeIa(tamanho: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: CoresIdv.borda),
            ),
            child: const _Digitando(),
          ),
        ],
      ),
    );
  }

  Widget _campoEnvio() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !widget.isLoading && !_desabilitado,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _enviar(),
              textInputAction: TextInputAction.send,
              style: fonteIdv(tamanho: 14),
              decoration: InputDecoration(
                hintText: _desabilitado
                    ? 'Indisponível por enquanto'
                    : widget.placeholder,
                hintStyle: fonteIdv(tamanho: 14, cor: CoresIdv.textoSecundario),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                filled: true,
                fillColor: CoresIdv.campo,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: CoresIdv.borda)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: CoresIdv.borda)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: CoresIdv.azul)),
                disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: CoresIdv.borda)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton.filled(
              tooltip: 'Enviar',
              onPressed: (widget.isLoading || _desabilitado) ? null : _enviar,
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.arrow_upward_rounded, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: CoresIdv.azul,
                disabledBackgroundColor: CoresIdv.azul.withOpacity(0.35),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pedido pronto clicável na conversa vazia.
class _Sugestao extends StatelessWidget {
  const _Sugestao({required this.texto, required this.aoTocar});
  final String texto;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CoresIdv.borda),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(texto,
                    style: fonteIdv(tamanho: 14, peso: FontWeight.w500)),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  size: 18, color: CoresIdv.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Digitando..." - três pontos que pulsam em sequência.
class _Digitando extends StatefulWidget {
  const _Digitando();

  @override
  State<_Digitando> createState() => _DigitandoState();
}

class _DigitandoState extends State<_Digitando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  double _brilho(int i) {
    final fase = (_anim.value * 3 - i) % 3;
    return fase < 1 ? 1 - fase : 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Opacity(
              // Cada ponto acende no seu terço da volta e apaga em seguida.
              opacity: 0.3 + 0.7 * _brilho(i),
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: CoresIdv.textoSecundario, shape: BoxShape.circle),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
