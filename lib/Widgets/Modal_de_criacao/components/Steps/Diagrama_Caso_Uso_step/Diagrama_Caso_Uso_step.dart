import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Chat_IA_Panel.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Modal_step.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Steps/Configuracao_Inicial_Projeto_step/components.dart';
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
  String get tabName => 'Casos de uso';

  @override
  String get ajuda =>
      'A IA gera um diagrama de casos de uso a partir dos requisitos funcionais. Esta aba é opcional.';

  @override
  IconData get icon => FontAwesomeIcons.diagramProject;

  @override
  List<Color> get cores => <Color>[Colors.deepPurple, Colors.indigo];

  // Layout próprio (conteúdo + painel de chat) - ver Modal_step.dart e
  // Modal_de_criacao.dart.
  @override
  bool get temPainelProprio => true;

  // O diagrama é opcional: o projeto pode ser criado sem abrir esta aba.
  @override
  bool get obrigatoria => false;

  @override
  void salvar() => _contentKey.currentState?.salvarNoDTO();

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
  // --- ASSISTENTE EM PAINEL FILHO ---
  // Dentro do modal de criação, o chat abre ao lado do modal (painel filho)
  // em vez de ocupar espaço aqui. Fora dele, continua no próprio layout.
  AssistenteIdv? _assistente;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _assistente = EscopoAssistenteIdv.maybeOf(context);
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    // O painel filho desenha o chat com o estado desta aba.
    if (_assistente?.aberto ?? false) _assistente!.atualizar();
  }

  void _registrarAssistente(String dono, bool disponivel) {
    final assistente = _assistente;
    if (assistente == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        assistente.registrar(dono, disponivel ? _chatFilho : null);
      }
    });
  }

  Widget _chatFilho(BuildContext context) => ChatIAPanel(
        mensagens: _mensagensChat,
        isLoading: _isConversando,
        onEnviar: _enviarMensagemChat,
        raio: 28,
        aoFechar: _assistente?.fechar,
        subtitulo: 'Ajusto o diagrama de casos de uso.',
        placeholder: 'Peça um ajuste no diagrama...',
        // A conversa ajusta um diagrama já gerado.
        avisoDesabilitado: _sessionId == null
            ? 'Gere o diagrama com o botão ao lado e depois peça os ajustes aqui.'
            : null,
        sugestoes: const [
          'Adicione um ator Administrador',
          'Inclua um caso de uso de cancelamento',
          'Simplifique o diagrama',
        ],
      );

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
      setState(() => _erro = mensagemErroIa(e));
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
      setState(() => _mensagensChat
          .add(ChatMensagem(texto: mensagemErroIa(e), deUsuario: false)));
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
    // Como em Requisitos, o assistente só aparece quando já há um diagrama
    // para conversar sobre ele.
    final comChat = _sessionId != null;
    _registrarAssistente('Casos de uso', true);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(child: _buildConteudoPrincipal()),
          ),
          if (comChat && _assistente == null) ...[
            const SizedBox(width: 20),
            SizedBox(
              width: 320,
              child: ChatIAPanel(
                mensagens: _mensagensChat,
                isLoading: _isConversando,
                onEnviar: _enviarMensagemChat,
                placeholder:
                    'ex: remova o ator Cliente, adicione um caso de uso de cancelamento...',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConteudoPrincipal() {
    final bool jaGerou = _imagemBytes != null || _mermaidCode != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BotaoIa(
          rotulo: jaGerou ? 'Gerar novamente' : 'Gerar diagrama com IA',
          rotuloCarregando: 'Gerando diagrama...',
          carregando: _isLoading,
          aoTocar: projetoDraft.requisitos.isEmpty ? null : _gerarDiagrama,
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
          icon: Icons.error_outline_rounded,
          cor: CoresIdv.vermelho,
          texto: _erro!);
    }

    if (projetoDraft.requisitos.isEmpty) {
      return _buildEstadoVazio(
        icon: Icons.list_alt_rounded,
        cor: CoresIdv.textoSecundario,
        texto: 'Nenhum requisito cadastrado ainda.\n'
            'Adicione ao menos um requisito na aba Requisitos para gerar o diagrama.',
      );
    }

    if (_imagemBytes != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_atores.isNotEmpty) ...[
            ComponentsConfiguracaoInicalProjeto.buildLabel(
                'Atores identificados'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _atores
                  .map((nome) => TagIdv(
                      texto: nome,
                      cor: CoresIdv.azul,
                      icone: Icons.person_outline_rounded))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            height: 380,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CoresIdv.borda),
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
            'Use o mouse para navegar e aproximar o diagrama.',
            style: fonteIdv(tamanho: 12, cor: CoresIdv.textoSecundario),
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
              color: CoresIdv.laranjaSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: CoresIdv.laranja, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _avisoRenderizacao ??
                        'Não foi possível desenhar o diagrama agora.',
                    style: fonteIdv(tamanho: 13, cor: CoresIdv.texto),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: CoresIdv.azul, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(
              _mermaidCode!,
              style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5),
            ),
          ),
        ],
      );
    }

    return _buildEstadoVazio(
      icon: Icons.account_tree_outlined,
      cor: CoresIdv.textoSecundario,
      texto:
          'Clique em "Gerar diagrama com IA" para ver os casos de uso deste projeto.',
    );
  }

  Widget _buildEstadoVazio(
      {required IconData icon, required Color cor, required String texto}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(icon, size: 36, color: cor.withOpacity(0.6)),
            const SizedBox(height: 10),
            Text(texto,
                textAlign: TextAlign.center,
                style: fonteIdv(cor: CoresIdv.textoSecundario, altura: 1.5)),
          ],
        ),
      ),
    );
  }
}
