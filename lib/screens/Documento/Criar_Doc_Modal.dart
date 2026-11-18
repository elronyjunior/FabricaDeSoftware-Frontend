import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/services/documento_service.dart';

class ModalCriarDocIA extends StatefulWidget {
  final int projetoId;
  final VoidCallback onSuccess; // Para atualizar a lista depois

  const ModalCriarDocIA({super.key, required this.projetoId, required this.onSuccess});

  @override
  State<ModalCriarDocIA> createState() => _ModalCriarDocIAState();
}

class _ModalCriarDocIAState extends State<ModalCriarDocIA> {
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _service = DocumentoService();

  String? _tipoSelecionado;
  String _formatoSelecionado = 'Texto';
  bool _isLoading = false;
  String _statusLabel = "Gerando...";
  String? _estagioAtual;
  double _progresso = 0.0;
  Timer? _progressoTimer;

  final List<Map<String, dynamic>> _tipos = [
    {'label': 'Arquitetura', 'icon': Icons.layers, 'color': Colors.blue},
    {'label': 'Requisitos', 'icon': Icons.description, 'color': Colors.purple},
    {'label': 'Casos de Uso', 'icon': Icons.book, 'color': Colors.green},
    {'label': 'API', 'icon': Icons.code, 'color': Colors.orange},
    {'label': 'Modelagem', 'icon': Icons.storage, 'color': Colors.pink},
    {'label': 'Testes', 'icon': Icons.bug_report, 'color': Colors.red},
    {'label': 'Código', 'icon': Icons.javascript, 'color': Colors.indigo},
  ];

  // Formato de saída: "Texto" gera o documento estruturado de sempre (vira
  // Google Doc); "Diagrama Mermaid" pede um diagrama Mermaid renderizado em
  // imagem, salvo só no banco (sem Google Docs).
  final List<Map<String, dynamic>> _formatos = [
    {'label': 'Texto', 'icon': Icons.article_outlined, 'color': Colors.blueGrey},
    {'label': 'Diagrama Mermaid', 'icon': Icons.account_tree_outlined, 'color': Colors.deepPurple},
  ];

  @override
  void dispose() {
    _progressoTimer?.cancel();
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _gerar() async {
    if (_tipoSelecionado == null || _tituloController.text.isEmpty) {
      avisar(context, "Selecione um tipo e preencha o título", tipo: TipoAviso.info);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusLabel = "Iniciando...";
      _estagioAtual = null;
      _progresso = 0.05;
    });

    try {
      await _service.gerarDocumentoIA(
        projetoId: widget.projetoId,
        tipo: _tipoSelecionado!,
        titulo: _tituloController.text,
        descricao: _descricaoController.text,
        formato: _formatoSelecionado == 'Diagrama Mermaid' ? 'mermaid' : 'texto',
        onStatusUpdate: (stage) {
          if (!mounted) return;
          setState(() {
            _statusLabel = _traduzirEstagio(stage);
            if (stage != _estagioAtual) {
              _estagioAtual = stage;
              _progresso = _progressoBase(stage);
              _iniciarProgressoSuave(stage);
            }
          });
        },
      );

      _progressoTimer?.cancel();
      if (mounted) {
        setState(() {
          _statusLabel = "Concluído!";
          _progresso = 1.0;
        });
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (mounted) {
        Navigator.pop(context); // Fecha o modal
        widget.onSuccess(); // Atualiza a tela de trás
        avisarApp("Documento criado com sucesso!", tipo: TipoAviso.sucesso);
      }
    } catch (e) {
      _progressoTimer?.cancel();
      if (mounted) {
        avisar(context, "Erro: $e", tipo: TipoAviso.erro);
      }
    } finally {
      _progressoTimer?.cancel();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _progressoBase(String stage) {
    switch (stage) {
      case 'buscando_dados_do_projeto':
        return 0.12;
      case 'gerando_conteudo_com_ia':
        return 0.30;
      case 'criando_documento_no_google_docs':
        return 0.82;
      case 'renderizando_diagrama':
        return 0.65;
      case 'salvando_documento':
        return 0.90;
      default:
        return _progresso;
    }
  }

  // Enquanto uma etapa demorada está em andamento (sem progresso real do
  // backend byte-a-byte), anima a barra suavemente em direção a um teto,
  // desacelerando perto dele — evita a sensação de "travado".
  void _iniciarProgressoSuave(String stage) {
    _progressoTimer?.cancel();
    final teto = switch (stage) {
      'gerando_conteudo_com_ia' => 0.75,
      'criando_documento_no_google_docs' => 0.97,
      'renderizando_diagrama' => 0.88,
      'salvando_documento' => 0.98,
      _ => _progresso,
    };

    if (teto <= _progresso) return;

    _progressoTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progresso += (teto - _progresso) * 0.06;
      });
    });
  }

  String _traduzirEstagio(String stage) {
    switch (stage) {
      case 'buscando_dados_do_projeto':
        return 'Buscando dados do projeto...';
      case 'gerando_conteudo_com_ia':
        return 'Gerando conteúdo com IA...';
      case 'criando_documento_no_google_docs':
        return 'Criando documento no Google Docs...';
      case 'renderizando_diagrama':
        return 'Renderizando diagrama...';
      case 'salvando_documento':
        return 'Salvando documento...';
      default:
        return 'Gerando...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PainelIdv(
      titulo: 'Novo documento com IA',
      ajuda: 'A IA gera o conteúdo a partir dos dados do projeto e monta o '
          'documento automaticamente.',
      rotuloAcao: _isLoading ? 'Gerando...' : 'Gerar documento',
      carregando: _isLoading,
      aoConfirmar: _gerar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoading) ...[
            _buildBarraDeProgresso(),
            const SizedBox(height: 24),
          ],
          AnimatedOpacity(
            opacity: _isLoading ? 0.45 : 1,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _isLoading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RotuloIdv('Tipo de documento', obrigatorio: true),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _tipos
                        .map((tipo) => _buildTypeCard(
                              tipo,
                              selecionado: _tipoSelecionado,
                              onSelect: (v) =>
                                  setState(() => _tipoSelecionado = v),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 22),
                  const RotuloIdv('Formato'),
                  OpcoesIdv<String>(
                    opcoes: [for (final f in _formatos) f['label'] as String],
                    valor: _formatoSelecionado,
                    aoMudar: (v) => setState(() => _formatoSelecionado = v),
                  ),
                  const SizedBox(height: 22),
                  CampoIdv(
                    rotulo: 'Título do documento',
                    controle: _tituloController,
                    obrigatorio: true,
                    dica: 'Ex.: Documento de arquitetura do sistema ERP',
                  ),
                  CampoIdv(
                    rotulo: 'Instruções para a IA',
                    controle: _descricaoController,
                    linhas: 3,
                    dica: 'Opcional: descreva o que você espera neste documento',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Etapa atual da geração e a barra de progresso (laranja da IDV).
  Widget _buildBarraDeProgresso() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CoresIdv.laranjaSuave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _statusLabel,
                  style: fonteIdv(tamanho: 13, peso: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${(_progresso.clamp(0, 1) * 100).round()}%",
                style: fonteIdv(
                    tamanho: 13, peso: FontWeight.w700, cor: CoresIdv.laranja),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _progresso.clamp(0, 1)),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(CoresIdv.laranja),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opção de tipo: azul-escuro quando escolhida, como as abas da IDV.
  Widget _buildTypeCard(
    Map<String, dynamic> item, {
    required String? selecionado,
    required ValueChanged<String> onSelect,
  }) {
    final isSelected = selecionado == item['label'];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSelect(item['label']),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 124,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? CoresIdv.azul : CoresIdv.campo,
            border: Border.all(
                color: isSelected ? CoresIdv.azul : CoresIdv.borda),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(item['icon'],
                  color: isSelected ? CoresIdv.laranja : CoresIdv.textoSecundario,
                  size: 24),
              const SizedBox(height: 8),
              Text(
                item['label'],
                textAlign: TextAlign.center,
                style: fonteIdv(
                  tamanho: 12.5,
                  peso: FontWeight.w600,
                  cor: isSelected ? Colors.white : CoresIdv.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
