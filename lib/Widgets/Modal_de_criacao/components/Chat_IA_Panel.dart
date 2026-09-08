import 'package:flutter/material.dart';

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

  const ChatIAPanel({
    super.key,
    required this.mensagens,
    required this.isLoading,
    required this.onEnviar,
    this.placeholder = 'Digite sua mensagem...',
    this.avisoDesabilitado,
  });

  @override
  State<ChatIAPanel> createState() => _ChatIAPanelState();
}

class _ChatIAPanelState extends State<ChatIAPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant ChatIAPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mensagens.length != oldWidget.mensagens.length || widget.isLoading != oldWidget.isLoading) {
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

  void _enviar() {
    final texto = _controller.text.trim();
    final desabilitado = widget.avisoDesabilitado != null;
    if (texto.isEmpty || widget.isLoading || desabilitado) return;
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
    final desabilitado = widget.avisoDesabilitado != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.06),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: const Row(
              children: [
                Icon(Icons.smart_toy_outlined, size: 18, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text("Assistente IA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: widget.mensagens.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        desabilitado ? widget.avisoDesabilitado! : widget.placeholder,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.mensagens.length + (widget.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == widget.mensagens.length) {
                        return _buildBolhaDigitando();
                      }
                      return _buildBolha(widget.mensagens[index]);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !widget.isLoading && !desabilitado,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _enviar(),
                    decoration: InputDecoration(
                      hintText: desabilitado ? widget.avisoDesabilitado : widget.placeholder,
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: (widget.isLoading || desabilitado) ? null : _enviar,
                  icon: widget.isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, size: 18),
                  style: IconButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBolha(ChatMensagem msg) {
    final cor = msg.deUsuario ? Colors.deepPurple : Colors.white;
    final corTexto = msg.deUsuario ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: msg.deUsuario ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(12),
            border: msg.deUsuario ? null : Border.all(color: Colors.grey.shade200),
          ),
          child: Text(msg.texto, style: TextStyle(color: corTexto, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildBolhaDigitando() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const SizedBox(
            width: 28,
            height: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Pontinho(),
                _Pontinho(),
                _Pontinho(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Indicador de "digitando..." - três pontos estáticos, suficiente pra
// indicar carregamento sem precisar de animação.
class _Pontinho extends StatelessWidget {
  const _Pontinho();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
    );
  }
}
