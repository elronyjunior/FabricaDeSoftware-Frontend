import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:flutter/material.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/models/tecnologia.dart';
import 'package:provider/provider.dart';
import 'package:fabrica_software_app/providers/tecnologias_provider.dart';

enum TecnologiaModalMode {
  view,
  edit,
  delete,
  create,
}

class TecnologiaModal extends StatefulWidget {
  final TecnologiaModalMode mode;
  final Tecnologia? tecnologia;

  const TecnologiaModal({
    super.key,
    required this.mode,
    this.tecnologia,
  });

  @override
  State<TecnologiaModal> createState() => _TecnologiaModalState();
}

class _TecnologiaModalState extends State<TecnologiaModal> {
  late TextEditingController _nomeController;
  late TextEditingController _categoriaController;
  late TextEditingController _descricaoController;
  
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.tecnologia?.nome ?? '');
    _categoriaController = TextEditingController(text: widget.tecnologia?.categoria ?? '');
    _descricaoController = TextEditingController(text: widget.tecnologia?.descricao ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _categoriaController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  bool get _visualizando => widget.mode == TecnologiaModalMode.view;

  @override
  Widget build(BuildContext context) {
    if (widget.mode == TecnologiaModalMode.delete) {
      return ConfirmacaoIdv(
        titulo: 'Excluir tecnologia',
        mensagem: '${widget.tecnologia!.nome} será excluída. '
            'Essa ação não pode ser desfeita.',
        rotuloAcao: 'Excluir tecnologia',
        carregando: _isLoading,
        aoConfirmar: _excluir,
      );
    }

    final (titulo, acao) = switch (widget.mode) {
      TecnologiaModalMode.view => ('Detalhes da tecnologia', null),
      TecnologiaModalMode.edit => ('Editar tecnologia', 'Salvar alterações'),
      _ => ('Nova tecnologia', 'Criar tecnologia'),
    };

    return PainelIdv(
      titulo: titulo,
      rotuloAcao: acao,
      carregando: _isLoading,
      aoConfirmar: _salvar,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinhaCamposIdv(children: [
              CampoIdv(
                rotulo: 'Nome',
                controle: _nomeController,
                obrigatorio: true,
                somenteLeitura: _visualizando,
                dica: 'Ex.: Flutter',
              ),
              CampoIdv(
                rotulo: 'Categoria',
                controle: _categoriaController,
                somenteLeitura: _visualizando,
                dica: 'Ex.: Framework',
              ),
            ]),
            CampoIdv(
              rotulo: 'Descrição',
              controle: _descricaoController,
              somenteLeitura: _visualizando,
              dica: 'Para que a tecnologia é usada',
              linhas: 4,
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> get _dados => {
        'nome': _nomeController.text,
        'categoria': _categoriaController.text.isEmpty
            ? null
            : _categoriaController.text,
        'descricao': _descricaoController.text.isEmpty
            ? null
            : _descricaoController.text,
      };

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    final provider = context.read<TecnologiasProvider>();
    try {
      if (widget.mode == TecnologiaModalMode.edit) {
        await provider.atualizarTecnologia(widget.tecnologia!.id!, _dados);
      } else {
        await provider.criarTecnologia(_dados);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      avisar(context, 'Não foi possível salvar a tecnologia: $e');
    }
  }

  Future<void> _excluir() async {
    setState(() => _isLoading = true);
    try {
      await context
          .read<TecnologiasProvider>()
          .excluirTecnologia(widget.tecnologia!.id!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      avisar(context, 'Não foi possível excluir a tecnologia: $e');
    }
  }
}
