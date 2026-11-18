import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/models/recurso.dart';
import 'package:provider/provider.dart';
import 'package:fabrica_software_app/providers/recursos_provider.dart';

enum RecursoModalMode {
  view,
  edit,
  delete,
  create,
}

class RecursoModal extends StatefulWidget {
  final RecursoModalMode mode;
  final Recurso? recurso;

  const RecursoModal({
    super.key,
    required this.mode,
    this.recurso,
  });

  @override
  State<RecursoModal> createState() => _RecursoModalState();
}

class _RecursoModalState extends State<RecursoModal> {
  late TextEditingController _nomeController;
  late TextEditingController _tipoController;
  late TextEditingController _descricaoController;
  late TextEditingController _criadoPorIdController;
  late bool _disponivel;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.recurso?.nome ?? '');
    _tipoController = TextEditingController(text: widget.recurso?.tipo ?? '');
    _descricaoController = TextEditingController(text: widget.recurso?.descricao ?? '');
    _criadoPorIdController = TextEditingController(text: widget.recurso?.criadoPorId?.toString() ?? '');
    _disponivel = widget.recurso?.disponivel ?? true;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _tipoController.dispose();
    _descricaoController.dispose();
    _criadoPorIdController.dispose();
    super.dispose();
  }

  bool get _visualizando => widget.mode == RecursoModalMode.view;

  @override
  Widget build(BuildContext context) {
    if (widget.mode == RecursoModalMode.delete) {
      return ConfirmacaoIdv(
        titulo: 'Excluir recurso',
        mensagem: '${widget.recurso!.nome} será excluído. '
            'Essa ação não pode ser desfeita.',
        rotuloAcao: 'Excluir recurso',
        carregando: _isLoading,
        aoConfirmar: _excluir,
      );
    }

    final (titulo, acao) = switch (widget.mode) {
      RecursoModalMode.view => ('Detalhes do recurso', null),
      RecursoModalMode.edit => ('Editar recurso', 'Salvar alterações'),
      _ => ('Novo recurso', 'Criar recurso'),
    };

    return PainelIdv(
      titulo: titulo,
      rotuloAcao: acao,
      carregando: _isLoading,
      aoConfirmar: _salvar,
      child: Form(key: _formKey, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final recurso = widget.recurso;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinhaCamposIdv(children: [
          _campo('Nome', _nomeController,
              obrigatorio: true, dica: 'Ex.: Notebook Dell'),
          _campo('Tipo', _tipoController,
              obrigatorio: true, dica: 'Ex.: Equipamento'),
        ]),
        CampoIdv(
          rotulo: 'Descrição',
          controle: _descricaoController,
          somenteLeitura: _visualizando,
          dica: 'Para que serve, onde fica...',
          linhas: 3,
        ),
        const RotuloIdv('Disponibilidade'),
        _Disponibilidade(
          disponivel: _disponivel,
          aoMudar: _visualizando
              ? null
              : (v) => setState(() => _disponivel = v),
        ),
        const SizedBox(height: 18),
        // O criador só é informado na criação (não se edita depois).
        if (widget.mode == RecursoModalMode.create)
          _campo('ID do criador', _criadoPorIdController,
              obrigatorio: true,
              teclado: TextInputType.number,
              formatadores: [FilteringTextInputFormatter.digitsOnly]),
        if (_visualizando)
          LinhaCamposIdv(children: [
            CampoIdv(
              rotulo: 'ID do criador',
              valorInicial: recurso?.criadoPorId?.toString(),
              somenteLeitura: true,
            ),
            CampoIdv(
              rotulo: 'Criado em',
              valorInicial: recurso?.dataCriacao?.toString(),
              somenteLeitura: true,
            ),
          ]),
      ],
    );
  }

  Widget _campo(String rotulo, TextEditingController controle,
      {bool obrigatorio = false,
      String? dica,
      TextInputType? teclado,
      List<TextInputFormatter>? formatadores}) {
    return CampoIdv(
      rotulo: rotulo,
      controle: controle,
      obrigatorio: obrigatorio,
      somenteLeitura: _visualizando,
      dica: dica,
      teclado: teclado,
      formatadores: formatadores,
    );
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    final provider = context.read<RecursosProvider>();
    final data = {
      'nome': _nomeController.text,
      'tipo': _tipoController.text,
      'disponivel': _disponivel,
      'descricao':
          _descricaoController.text.isEmpty ? null : _descricaoController.text,
    };
    try {
      if (widget.mode == RecursoModalMode.edit) {
        await provider.atualizarRecurso(widget.recurso!.id!, data);
      } else {
        data['criado_por_id'] = int.parse(_criadoPorIdController.text);
        await provider.criarRecurso(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      avisar(context, 'Não foi possível salvar o recurso: $e');
    }
  }

  Future<void> _excluir() async {
    setState(() => _isLoading = true);
    try {
      await context.read<RecursosProvider>().excluirRecurso(widget.recurso!.id!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      avisar(context, 'Não foi possível excluir o recurso: $e');
    }
  }
}

/// Interruptor "Disponível" dentro de uma caixa no visual dos campos.
class _Disponibilidade extends StatelessWidget {
  const _Disponibilidade({required this.disponivel, required this.aoMudar});
  final bool disponivel;
  final ValueChanged<bool>? aoMudar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: CoresIdv.campo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CoresIdv.borda),
      ),
      child: Row(
        children: [
          Icon(
            disponivel
                ? Icons.check_circle_rounded
                : Icons.do_not_disturb_on_outlined,
            size: 20,
            color: disponivel ? CoresIdv.verde : CoresIdv.textoSecundario,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              disponivel ? 'Disponível para uso' : 'Indisponível',
              style: fonteIdv(peso: FontWeight.w500),
            ),
          ),
          Switch(
            value: disponivel,
            onChanged: aoMudar,
            activeColor: Colors.white,
            activeTrackColor: CoresIdv.laranja,
          ),
        ],
      ),
    );
  }
}
