import 'dart:typed_data';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fabrica_software_app/models/documento_conteudo.dart';
import 'package:fabrica_software_app/providers/documento_editor_provider.dart';
import 'package:fabrica_software_app/providers/secao_hover_provider.dart';
import 'package:fabrica_software_app/screens/Documento/components/Secao_Widget.dart';
import 'package:fabrica_software_app/screens/Documento/components/SecaoRevisao_Widget.dart';
import 'package:fabrica_software_app/services/documento_pdf_builder.dart';
import 'package:fabrica_software_app/services/documento_service.dart';

const _corPrimaria = Color(0xFF8B5CF6);

class VisualizarDocumentoScreen extends StatefulWidget {
  final int documentoId;
  final String nomeArquivo;
  final String arquivoUrl;

  const VisualizarDocumentoScreen({
    super.key,
    required this.documentoId,
    required this.nomeArquivo,
    required this.arquivoUrl,
  });

  @override
  State<VisualizarDocumentoScreen> createState() => _VisualizarDocumentoScreenState();
}

class _VisualizarDocumentoScreenState extends State<VisualizarDocumentoScreen> {
  late final SecaoHoverProvider _hoverProvider;
  DocumentoEditorProvider? _editorProvider; // só criado pro formato "texto"

  bool _carregando = true;
  String? _erro;
  Map<String, dynamic>? _conteudoDiagrama; // não-nulo = formato "mermaid"

  @override
  void initState() {
    super.initState();
    _hoverProvider = SecaoHoverProvider();
    _decidirFormatoECarregar();
  }

  // Os dois formatos ("texto" e "diagrama Mermaid") são estruturalmente
  // diferentes demais pra passar pelo mesmo DocumentoEditorProvider (que é
  // todo montado em torno de secoes/tabelas editáveis, retrabalho de seções
  // com IA, export em PDF por seção etc. - nada disso existe pra um
  // diagrama). Por isso decidimos o formato ANTES de montar qualquer coisa,
  // olhando o conteudo_json bruto, e só então seguimos por um dos dois
  // caminhos completamente separados.
  Future<void> _decidirFormatoECarregar() async {
    try {
      final conteudo = await DocumentoService().getConteudoDocumento(widget.documentoId);

      if (!mounted) return;

      if (conteudo != null && conteudo['formato'] == 'mermaid') {
        setState(() {
          _conteudoDiagrama = conteudo;
          _carregando = false;
        });
        return;
      }

      // Formato "texto" (ou documento legado sem conteudo_json): segue o
      // fluxo de edição já existente.
      _editorProvider = DocumentoEditorProvider(documentoId: widget.documentoId, hoverProvider: _hoverProvider);
      await _editorProvider!.carregar();
      if (!mounted) return;
      setState(() => _carregando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Erro ao carregar documento: $e';
        _carregando = false;
      });
    }
  }

  @override
  void dispose() {
    _hoverProvider.dispose();
    _editorProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Carregando/erro também ganham a AppBar com voltar (antes não havia como
    // sair da tela se o documento travasse ou desse erro).
    if (_carregando) {
      return Scaffold(appBar: _appBarSimples(context), body: const Center(child: CircularProgressIndicator()));
    }

    if (_erro != null) {
      return Scaffold(
        appBar: _appBarSimples(context),
        body: Center(child: Text(_erro!, style: TextStyle(color: Colors.red.shade700))),
      );
    }

    if (_conteudoDiagrama != null) {
      return _VisualizarDiagramaMermaidBody(nomeArquivo: widget.nomeArquivo, conteudo: _conteudoDiagrama!);
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _hoverProvider),
        ChangeNotifierProvider.value(value: _editorProvider!),
      ],
      child: _VisualizarDocumentoBody(nomeArquivo: widget.nomeArquivo, arquivoUrl: widget.arquivoUrl),
    );
  }

  // Mesmo padrão da AppBar do estado normal (fundo branco, seta preta).
  PreferredSizeWidget _appBarSimples(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(
        widget.nomeArquivo,
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// Corpo dedicado ao formato "Diagrama Mermaid" - sem edição de seções, sem
// Google Docs (esse formato não passa por lá, ver salvarDocumentoMermaid.js
// no backend), só a imagem já renderizada e o código Mermaid bruto. Mesmo
// visual usado no passo do wizard (Diagrama_Caso_Uso_step.dart).
class _VisualizarDiagramaMermaidBody extends StatelessWidget {
  final String nomeArquivo;
  final Map<String, dynamic> conteudo;

  const _VisualizarDiagramaMermaidBody({required this.nomeArquivo, required this.conteudo});

  @override
  Widget build(BuildContext context) {
    final titulo = (conteudo['titulo'] as String?) ?? nomeArquivo;
    final atores = (conteudo['atores'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final mermaid = conteudo['mermaid'] as String?;
    final imagemBase64 = conteudo['imagem_base64'] as String?;
    // base64 corrompido lançava FormatException dentro do build (tela
    // vermelha). Com null, cai na mensagem "Não foi possível carregar...".
    Uint8List? imagemBytes;
    if (imagemBase64 != null) {
      try {
        imagemBytes = base64Decode(imagemBase64);
      } catch (_) {
        imagemBytes = null;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          nomeArquivo,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (atores.isNotEmpty) ...[
                    Text('Elementos identificados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: atores.map((a) => _buildChip(a)).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (imagemBytes != null)
                    Container(
                      height: 460,
                      width: double.infinity,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                      clipBehavior: Clip.antiAlias,
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4,
                        boundaryMargin: const EdgeInsets.all(40),
                        child: Center(
                          child: Image.memory(
                            imagemBytes,
                            // Bytes que não são uma imagem válida: mostra o aviso no lugar.
                            errorBuilder: (_, __, ___) => Text('Não foi possível carregar a imagem do diagrama.', style: TextStyle(color: Colors.grey.shade600)),
                          ),
                        ),
                      ),
                    )
                  else
                    Text('Não foi possível carregar a imagem do diagrama.', style: TextStyle(color: Colors.grey.shade600)),
                  if (mermaid != null) ...[
                    const SizedBox(height: 20),
                    Text('Código Mermaid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                      child: SelectableText(
                        mermaid,
                        style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String nome) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _corPrimaria.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _corPrimaria.withOpacity(0.2)),
      ),
      child: Text(nome, style: const TextStyle(color: _corPrimaria, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _VisualizarDocumentoBody extends StatefulWidget {
  final String nomeArquivo;
  final String arquivoUrl;

  const _VisualizarDocumentoBody({required this.nomeArquivo, required this.arquivoUrl});

  @override
  State<_VisualizarDocumentoBody> createState() => _VisualizarDocumentoBodyState();
}

class _VisualizarDocumentoBodyState extends State<_VisualizarDocumentoBody> {
  static const double _larguraPagina = 820;
  static const double _zoomMinimo = 0.5;
  static const double _zoomMaximo = 1.5;

  double _zoom = 1.0;

  void _diminuirZoom() => setState(() {
        final novo = _zoom - 0.1;
        _zoom = novo < _zoomMinimo ? _zoomMinimo : novo;
      });

  void _aumentarZoom() => setState(() {
        final novo = _zoom + 0.1;
        _zoom = novo > _zoomMaximo ? _zoomMaximo : novo;
      });

  void _resetarZoom() => setState(() => _zoom = 1.0);

  Future<void> _abrirNoGoogleDocs(BuildContext context) async {
    final uri = Uri.parse(widget.arquivoUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Não foi possível abrir';
      }
    } catch (e) {
      if (context.mounted) {
        avisar(context, 'Erro ao abrir o Google Docs', tipo: TipoAviso.erro);
      }
    }
  }

  Future<void> _exportarPdf(BuildContext context, DocumentoEditorProvider provider) async {
    final documento = provider.documento;
    if (documento == null) return;

    try {
      final bytes = await construirPdfDocumento(documento);
      await Printing.sharePdf(bytes: bytes, filename: '${widget.nomeArquivo}.pdf');
    } catch (e) {
      if (context.mounted) {
        avisar(context, 'Erro ao gerar o PDF', tipo: TipoAviso.erro);
      }
    }
  }

  Future<bool> _confirmarSaidaComAlteracoesPendentes(BuildContext context) async {
    final resultado = await mostrarDialogo<String>(
      context: context,
      builder: (ctx) => _DialogoAlteracoesPendentes(
        aoEscolher: (escolha) => Navigator.pop(ctx, escolha),
      ),
    );

    if (resultado == 'salvar') {
      if (!context.mounted) return false;
      return context.read<DocumentoEditorProvider>().salvar();
    }
    return resultado == 'descartar';
  }

  Future<void> _salvar(BuildContext context, DocumentoEditorProvider provider) async {
    final sucesso = await provider.salvar();
    if (!context.mounted) return;
    avisar(context, sucesso ? 'Documento salvo!' : 'Erro ao salvar documento', tipo: sucesso ? TipoAviso.sucesso : TipoAviso.erro);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentoEditorProvider>();

    return PopScope(
      canPop: !provider.isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final podeSair = await _confirmarSaidaComAlteracoesPendentes(context);
        if (podeSair && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade300,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            widget.nomeArquivo,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            TextButton.icon(
              onPressed: () => _abrirNoGoogleDocs(context),
              icon: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
              label: const Text('Abrir no Google Docs', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            _buildToolbar(context, provider),
            Expanded(child: _buildCorpo(context, provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, DocumentoEditorProvider provider) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (provider.documento == null || provider.modoRevisao) ? null : provider.alternarEdicao,
                  icon: Icon(provider.editMode ? Icons.visibility : Icons.edit, size: 16),
                  label: Text(provider.editMode ? 'Sair da Edição' : 'Editar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: provider.editMode ? Colors.grey.shade200 : _corPrimaria,
                    foregroundColor: provider.editMode ? Colors.black87 : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (provider.editMode) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: provider.adicionarSecaoRaiz,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Seção'),
                  ),
                ],
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: provider.documento == null ? null : provider.alternarModoRevisao,
                  icon: Icon(provider.modoRevisao ? Icons.visibility_off_outlined : Icons.difference_outlined, size: 16),
                  label: Text(provider.modoRevisao ? 'Ver Documento' : 'Ver Alterações'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: provider.modoRevisao ? Colors.white : Colors.deepOrange,
                    backgroundColor: provider.modoRevisao ? Colors.deepOrange : null,
                    side: const BorderSide(color: Colors.deepOrange),
                  ),
                ),
                const Spacer(),
                if (provider.editMode) ...[
                  Text(
                    provider.isDirty ? 'Alterações não salvas' : 'Tudo salvo',
                    style: TextStyle(
                      fontSize: 12,
                      color: provider.isDirty ? Colors.orange.shade800 : Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: (provider.isDirty && !provider.isSaving) ? () => _salvar(context, provider) : null,
                    icon: provider.isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: const Text('Salvar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                OutlinedButton.icon(
                  onPressed: provider.documento == null ? null : () => _exportarPdf(context, provider),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Salvar PDF'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                _buildControleZoom(),
                if (provider.modoRevisao) ...[
                  const Spacer(),
                  _buildLegenda(),
                ],
              ],
            ),
          ),
          if (provider.secoesSelecionadasParaRetrabalho.isNotEmpty) _buildBarraRetrabalhoIA(context, provider),
        ],
      ),
    );
  }

  Widget _buildBarraRetrabalhoIA(BuildContext context, DocumentoEditorProvider provider) {
    final quantidade = provider.secoesSelecionadasParaRetrabalho.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: _corPrimaria.withOpacity(0.08),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: _corPrimaria),
          const SizedBox(width: 8),
          Text(
            provider.retrabalhandoComIA
                ? (provider.estagioRetrabalho == 'gerando_reescrita_com_ia'
                    ? 'Reescrevendo com IA...'
                    : 'Processando...')
                : '$quantidade seção(ões) selecionada(s)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (provider.retrabalhandoComIA)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            TextButton(
              onPressed: provider.limparSelecaoParaRetrabalho,
              child: const Text('Limpar seleção'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _abrirDialogoRetrabalho(context, provider),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Retrabalhar com IA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _corPrimaria,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _abrirDialogoRetrabalho(BuildContext context, DocumentoEditorProvider provider) async {
    final controlador = TextEditingController();
    final quantidade = provider.secoesSelecionadasParaRetrabalho.length;

    final instrucao = await mostrarDialogo<String>(
      context: context,
      builder: (ctx) => PainelIdv(
        titulo: quantidade == 1
            ? 'Retrabalhar 1 seção com IA'
            : 'Retrabalhar $quantidade seções com IA',
        ajuda: 'A IA reescreve as seções selecionadas. Você revisa as '
            'mudanças antes de salvar.',
        rotuloAcao: 'Enviar para a IA',
        aoConfirmar: () => Navigator.pop(ctx, controlador.text),
        child: CampoIdv(
          rotulo: 'Instruções para a IA',
          controle: controlador,
          linhas: 4,
          dica: 'Opcional: o que a IA deve mudar nessa(s) seção(ões)?',
        ),
      ),
    );

    if (instrucao == null || !context.mounted) return;

    final sucesso = await provider.retrabalharSelecionadasComIA(instrucao);
    if (!context.mounted) return;

    avisar(context, sucesso ? 'Seções reescritas! Revise e clique em Salvar.' : 'Erro ao retrabalhar seções com IA', tipo: sucesso ? TipoAviso.sucesso : TipoAviso.erro);
  }

  Widget _buildControleZoom() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _zoom > _zoomMinimo ? _diminuirZoom : null,
          icon: const Icon(Icons.remove, size: 16),
          visualDensity: VisualDensity.compact,
          tooltip: 'Diminuir zoom',
        ),
        InkWell(
          onTap: _resetarZoom,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '${(_zoom * 100).round()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          onPressed: _zoom < _zoomMaximo ? _aumentarZoom : null,
          icon: const Icon(Icons.add, size: 16),
          visualDensity: VisualDensity.compact,
          tooltip: 'Aumentar zoom',
        ),
      ],
    );
  }

  Widget _buildLegenda() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendaItem(corFundoAlteracao, 'Adicionado/Alterado'),
        const SizedBox(width: 12),
        _buildLegendaItem(corFundoRemovido, 'Removido'),
      ],
    );
  }

  Widget _buildLegendaItem(Color cor, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildCorpo(BuildContext context, DocumentoEditorProvider provider) {
    if (provider.carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.erro != null) {
      return Center(child: Text(provider.erro!, style: TextStyle(color: Colors.red.shade700)));
    }

    final documento = provider.documento;
    if (documento == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Este documento não tem conteúdo editável no app.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'Documentos gerados antes desta atualização só podem ser vistos no Google Docs.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _abrirNoGoogleDocs(context),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Abrir no Google Docs'),
              style: ElevatedButton.styleFrom(backgroundColor: _corPrimaria, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    return _buildPagina(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(documento.titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if ((documento.sumarioExecutivo ?? '').isNotEmpty) ...[
            Text(
              'Sumário Executivo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(documento.sumarioExecutivo!, style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 20),
          ],
          if (provider.modoRevisao)
            for (final no in provider.arvoreRevisao) SecaoRevisaoWidget(no: no)
          else
            for (final secao in documento.secoes) SecaoWidget(secao: secao),
          if (documento.tabelas.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._buildTabelas(documento.tabelas),
          ],
          if ((documento.conclusao ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Conclusão',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(documento.conclusao!, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
        ],
      ),
    );
  }

  // Embrulha o conteúdo numa "folha" branca de proporção A4, centralizada
  // num fundo cinza (como Word/Google Docs), escalada pelo nível de zoom.
  Widget _buildPagina(Widget conteudo) {
    const alturaMinima = _larguraPagina * 1.414;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: SizedBox(
          width: _larguraPagina * _zoom,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: _larguraPagina,
              child: Container(
                constraints: const BoxConstraints(minHeight: alturaMinima),
                padding: const EdgeInsets.all(72),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 18, offset: const Offset(0, 6)),
                  ],
                ),
                child: conteudo,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTabelas(List<TabelaDocumento> tabelas) {
    return tabelas.map((tabela) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if ((tabela.titulo ?? '').isNotEmpty)
                  Text(tabela.titulo!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                  child: Text('não editável', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: tabela.cabecalhos
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      )
                      .toList(),
                ),
                for (final linha in tabela.linhas)
                  TableRow(
                    children: linha
                        .map(
                          (celula) => Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(celula, style: const TextStyle(fontSize: 12)),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }
}

/// Sair com alterações não salvas: salvar, descartar ou continuar editando.
/// Devolve 'salvar', 'descartar' ou 'cancelar'.
class _DialogoAlteracoesPendentes extends StatelessWidget {
  const _DialogoAlteracoesPendentes({required this.aoEscolher});
  final ValueChanged<String> aoEscolher;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StyleProjetos.sidebarAbertaRaio)),
      child: Theme(
        data: temaIdv(Theme.of(context)),
        child: SizedBox(
          width: 500,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: CoresIdv.laranjaSuave,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.save_outlined,
                      size: 21, color: CoresIdv.laranja),
                ),
                const SizedBox(height: 16),
                Text('Alterações não salvas',
                    style: fonteIdv(tamanho: 20, peso: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Deseja salvar suas alterações antes de sair?',
                    style:
                        fonteIdv(cor: CoresIdv.textoSecundario, altura: 1.45)),
                const SizedBox(height: 26),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    BotaoSecundarioIdv(
                      rotulo: 'Continuar editando',
                      aoTocar: () => aoEscolher('cancelar'),
                    ),
                    BotaoSecundarioIdv(
                      rotulo: 'Descartar',
                      aoTocar: () => aoEscolher('descartar'),
                    ),
                    BotaoPrincipalIdv(
                      rotulo: 'Salvar e sair',
                      aoTocar: () => aoEscolher('salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
