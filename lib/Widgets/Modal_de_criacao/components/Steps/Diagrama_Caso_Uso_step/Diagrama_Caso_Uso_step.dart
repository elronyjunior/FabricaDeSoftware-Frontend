import 'dart:convert';
import 'dart:typed_data';

import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Chat_IA_Panel.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Modal_step.dart';
import 'package:fabrica_software_app/config/projeto_dto.dart';
import 'package:fabrica_software_app/providers/modal_criacao_projeto_provider.dart';
import 'package:fabrica_software_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

// Passo do wizard: pede pra IA gerar um diagrama de casos de uso (Mermaid ->
// PNG via backend, usando mermaid.ink) a partir dos requisitos já levantados
// no passo anterior, e permite pedir ajustes específicos conversando com a
// IA num painel à direita (memória de verdade fica no backend - ver
// ApiService.refinarDiagramaCasoUso e chatSessionStore.js). Esse
// refinamento só afeta o diagrama, nunca a lista de Requisitos do passo
// anterior. Não bloqueia o avanço do wizard (validar() sempre true) - o
// diagrama atual (se houver) é gravado no ProjetoDTO em salvarNoDTO() e
// persistido no banco só ao final da criação do projeto (ver
// ApiService.criarProjetoCompleto).
//
// Usa PNG (Image.memory), não SVG: o SVG do mermaid.ink estiliza os nós via
// <style> com seletores de classe, que o flutter_svg não resolve - o
// diagrama aparecia todo preto. PNG já vem rasterizado com as cores certas.
class DiagramaCasoUsoStep extends ModalStep {
  @override
  String get title => 'Diagrama de Casos de Uso';

  @override
  String get tabName => 'Casos de Uso';

  @override
  IconData get icon => FontAwesomeIcons.diagramProject;

  @override
  List<Color> get cores => <Color>[Colors.deepPurple, Colors.indigo];

  // Layout próprio (conteúdo + painel de chat) - ver Modal_step.dart e
  // Modal_de_criacao.dart.
  @override
  bool get temPainelProprio => true;

  final GlobalKey<_DiagramaCasoUsoContentState> _contentKey = GlobalKey();

  @override
  Widget buildBody(BuildContext context) {
    return _DiagramaCasoUsoContent(key: _contentKey);
  }

  @override
  Widget buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botão Cancelar
          TextButton.icon(
            onPressed: () {
              // Regra: Sair perde tudo
              projetoDraft.clear();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close, size: 16, color: Colors.black87),
            label: const Text('Cancelar',
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.normal)),
          ),

          Row(
            children: [
              // Botão Voltar
              OutlinedButton(
                onPressed: () {
                  if (_contentKey.currentState != null) {
                    _contentKey.currentState!.limparDadosDestaEtapa();
                  }
                  context.read<ModalCriacaoProjetoProvider>().previousIndex();
                },
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Voltar',
                    style: TextStyle(color: Colors.black87)),
              ),

              const SizedBox(width: 12),

              // Botão Próxima Etapa - este passo nunca bloqueia o avanço
              ElevatedButton(
                onPressed: () {
                  if (_contentKey.currentState != null) {
                    _contentKey.currentState!.salvarNoDTO();
                  }
                  context.read<ModalCriacaoProjetoProvider>().nextIndex();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Row(
                  children: const [
                    Text('Próxima etapa'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiagramaCasoUsoContent extends StatefulWidget {
  const _DiagramaCasoUsoContent({super.key});

  @override
  State<_DiagramaCasoUsoContent> createState() =>
      _DiagramaCasoUsoContentState();
}

class _DiagramaCasoUsoContentState extends State<_DiagramaCasoUsoContent> {
  bool _isLoading = false;
  bool _isConversando = false;
  String?
      _sessionId; // não-nulo = já dá pra conversar (ver ApiService.refinarDiagramaCasoUso)
  String? _tituloAtual;
  String? _mermaidCode;
  Uint8List? _imagemBytes;
  List<String> _atores = [];
  String? _erro; // erro de rede/API - sem nada pra mostrar
  String? _avisoRenderizacao; // IA respondeu mas a imagem não pôde ser gerada

  final List<ChatMensagem> _mensagensChat = [];

  @override
  void initState() {
    super.initState();
    // Adiado pro pós-primeiro-frame: dispara a geração automática assim que
    // o passo abre (o usuário já chega aqui com requisitos prontos), mas só
    // depois que o widget está montado na árvore.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (projetoDraft.requisitos.isNotEmpty && mounted) {
        _gerarDiagrama();
      }
    });
  }

  // --- CONTRATO USADO PELO FOOTER (mesmo formato do passo de Requisitos) ---

  void limparDadosDestaEtapa() {
    setState(() {
      _sessionId = null;
      _tituloAtual = null;
      _mermaidCode = null;
      _imagemBytes = null;
      _atores = [];
      _erro = null;
      _avisoRenderizacao = null;
      _mensagensChat.clear();
    });
  }

  // Grava o diagrama atual (se houver) no ProjetoDTO - é só isso que permite
  // ApiService.criarProjetoCompleto salvá-lo no banco depois que o projeto
  // for criado. Sem diagrama gerado, não escreve nada (não é obrigatório).
  void salvarNoDTO() {
    projetoDraft.diagramaCasoUsoTitulo = _tituloAtual;
    projetoDraft.diagramaCasoUsoMermaid = _mermaidCode;
    projetoDraft.diagramaCasoUsoImagemBase64 =
        _imagemBytes != null ? base64Encode(_imagemBytes!) : null;
    projetoDraft.diagramaCasoUsoAtores = _atores;
  }

  // --- INTEGRAÇÃO COM IA NO BACKEND ---

  // "Gerar"/"Gerar novamente": começa uma sessão de conversa do zero -
  // qualquer ajuste pedido antes (via chat) é esquecido.
  Future<void> _gerarDiagrama() async {
    if (projetoDraft.requisitos.isEmpty) return;

    setState(() {
      _isLoading = true;
      _erro = null;
      _avisoRenderizacao = null;
      _mensagensChat.clear();
    });

    try {
      final nomeProjeto = projetoDraft.nome ?? 'Novo Projeto';
      final resultado = await ApiService.gerarDiagramaCasoUso(
        nomeProjeto,
        projetoDraft.escopo,
        projetoDraft.requisitos,
      );

      _aplicarResultado(resultado);
    } catch (e) {
      setState(() => _erro = 'Não foi possível gerar o diagrama: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Mensagem enviada pelo chat: continua a mesma sessão de conversa
  // (_sessionId) - não afeta a lista de Requisitos do passo anterior, só o
  // diagrama.
  Future<void> _enviarMensagemChat(String mensagem) async {
    if (_sessionId == null || _isConversando) return;

    setState(() {
      _mensagensChat.add(ChatMensagem(texto: mensagem, deUsuario: true));
      _isConversando = true;
    });

    try {
      final resultado =
          await ApiService.refinarDiagramaCasoUso(_sessionId!, mensagem);
      _aplicarResultado(resultado);
    } catch (e) {
      setState(() => _mensagensChat.add(ChatMensagem(
          texto: 'Erro ao ajustar o diagrama: $e', deUsuario: false)));
    } finally {
      if (mounted) setState(() => _isConversando = false);
    }
  }

  void _aplicarResultado(Map<String, dynamic> resultado) {
    final imagemBase64 = resultado['imagem_base64'] as String?;
    final respostaChat = resultado['resposta_chat'] as String?;

    setState(() {
      _sessionId = resultado['sessionId'] as String? ?? _sessionId;
      _tituloAtual = resultado['titulo'] as String?;
      _mermaidCode = resultado['mermaid'] as String?;
      _imagemBytes = imagemBase64 != null ? base64Decode(imagemBase64) : null;
      _atores = (resultado['atores'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      _avisoRenderizacao = resultado['aviso_renderizacao'] as String?;
      if (respostaChat != null && respostaChat.trim().isNotEmpty) {
        _mensagensChat.add(ChatMensagem(texto: respostaChat, deUsuario: false));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: SingleChildScrollView(child: _buildConteudoPrincipal()),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 300,
            child: ChatIAPanel(
              mensagens: _mensagensChat,
              isLoading: _isConversando,
              onEnviar: _enviarMensagemChat,
              placeholder:
                  'ex: remova o ator Cliente, adicione um caso de uso de cancelamento...',
              avisoDesabilitado: _sessionId == null
                  ? 'Gere um diagrama primeiro para poder conversar.'
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudoPrincipal() {
    final bool jaGerou = _imagemBytes != null || _mermaidCode != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- SEÇÃO EXPLICATIVA ---
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.hub_outlined, color: Color(0xFF2962FF), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "A IA gera um diagrama de casos de uso a partir dos requisitos funcionais cadastrados. "
                  "Este passo é só uma visualização - nada aqui é salvo ainda.",
                  style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- BOTÃO GERAR / REGENERAR ---
        Container(
          width: double.infinity,
          height: 45,
          decoration: BoxDecoration(
            gradient: _isLoading
                ? const LinearGradient(colors: [Colors.grey, Colors.blueGrey])
                : const LinearGradient(
                    colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)]),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              if (!_isLoading)
                BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (_isLoading || projetoDraft.requisitos.isEmpty)
                  ? null
                  : _gerarDiagrama,
              borderRadius: BorderRadius.circular(8),
              child: Center(
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text("Gerando diagrama...",
                              style: TextStyle(color: Colors.white)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(FontAwesomeIcons.wandMagicSparkles,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            jaGerou
                                ? "Gerar novamente"
                                : "Gerar Diagrama com IA",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _buildConteudo(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildConteudo() {
    if (_isLoading && !(_imagemBytes != null || _mermaidCode != null)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_erro != null) {
      return _buildEstadoVazio(
          icon: Icons.error_outline, cor: Colors.red, texto: _erro!);
    }

    if (projetoDraft.requisitos.isEmpty) {
      return _buildEstadoVazio(
        icon: Icons.list_alt,
        cor: Colors.grey,
        texto: "Nenhum requisito cadastrado na etapa anterior.\n"
            "Volte e adicione ao menos um requisito para gerar o diagrama.",
      );
    }

    if (_imagemBytes != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_atores.isNotEmpty) ...[
            const Text("Atores identificados",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _atores.map(_buildAtorChip).toList(),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            height: 380,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(40),
              child: Center(child: Image.memory(_imagemBytes!)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Use o mouse/dedos para navegar e aproximar o diagrama.",
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      );
    }

    if (_mermaidCode != null) {
      // A IA respondeu mas o mermaid.ink não conseguiu renderizar agora -
      // ainda mostramos o código gerado em vez de deixar a tela vazia.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _avisoRenderizacao ??
                        "Não foi possível renderizar o diagrama visualmente agora.",
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8)),
            child: SelectableText(
              _mermaidCode!,
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 12),
            ),
          ),
        ],
      );
    }

    return _buildEstadoVazio(
      icon: Icons.account_tree_outlined,
      cor: Colors.grey,
      texto:
          'Clique em "Gerar Diagrama com IA" para visualizar os casos de uso deste projeto.',
    );
  }

  Widget _buildEstadoVazio(
      {required IconData icon, required Color cor, required String texto}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: cor.withOpacity(0.5)),
            const SizedBox(height: 10),
            Text(texto,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildAtorChip(String nome) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 14, color: Colors.indigo),
          const SizedBox(width: 4),
          Text(nome,
              style: const TextStyle(
                  color: Colors.indigo,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
