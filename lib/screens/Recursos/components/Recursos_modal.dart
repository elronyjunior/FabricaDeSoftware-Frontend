import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/models/recurso.dart';
import 'package:fabrica_software_app/models/recurso_projeto.dart';
import 'package:provider/provider.dart';
import 'package:fabrica_software_app/providers/recursos_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/services/auth_service.dart';
import 'package:fabrica_software_app/services/recursos_service.dart';
import 'package:intl/intl.dart';

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
  late bool _disponivel;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.recurso?.nome ?? '');
    _tipoController = TextEditingController(text: widget.recurso?.tipo ?? '');
    _descricaoController = TextEditingController(text: widget.recurso?.descricao ?? '');
    _disponivel = widget.recurso?.disponivel ?? true;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _tipoController.dispose();
    _descricaoController.dispose();
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
          _visualizando
              ? _campo('Tipo', _tipoController)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RotuloIdv('Tipo', obrigatorio: true),
                      SelecaoIdv<String>(
                        hint: 'Escolha o tipo',
                        valor: _tipoController.text.trim().isEmpty
                            ? null
                            : _tipoController.text.trim(),
                        itens: _opcoesTipo,
                        rotulo: (t) => t,
                        aoMudar: (t) =>
                            setState(() => _tipoController.text = t ?? ''),
                      ),
                    ],
                  ),
                ),
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
        // O criador é o usuário logado (preenchido sozinho ao criar).
        if (_visualizando) ...[
          CampoIdv(
            rotulo: 'Cadastrado em',
            valorInicial: recurso?.dataCriacao == null
                ? null
                : DateFormat('dd/MM/yyyy').format(recurso!.dataCriacao!.toLocal()),
            somenteLeitura: true,
          ),
          const SizedBox(height: 6),
          const SecaoIdv('Usado nos projetos',
              descricao: 'Vínculos feitos em cada projeto, com o custo/hora.'),
          _ProjetosDoRecurso(recursoId: recurso!.id!),
        ],
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

  /// Tipos de recurso. Um tipo antigo, digitado à mão, continua na lista
  /// ao editar.
  static const tiposRecurso = [
    'Equipamento',
    'Software / licença',
    'Assinatura / plano',
    'Infraestrutura',
    'Serviço',
    'Mão de obra',
    'Material',
    'Outro',
  ];

  List<String> get _opcoesTipo {
    final atual = _tipoController.text.trim();
    return [
      ...tiposRecurso,
      if (atual.isNotEmpty && !tiposRecurso.contains(atual)) atual,
    ];
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_tipoController.text.trim().isEmpty) {
      avisar(context, 'Escolha o tipo do recurso.', tipo: TipoAviso.info);
      return;
    }
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
      final bool ok;
      if (widget.mode == RecursoModalMode.edit) {
        ok = await provider.atualizarRecurso(widget.recurso!.id!, data);
      } else {
        data['criado_por_id'] = await AuthService.instance.userId;
        ok = await provider.criarRecurso(data);
      }
      if (!mounted) return;
      if (!ok) throw provider.error ?? 'erro desconhecido';
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      avisar(context, 'Não foi possível salvar o recurso: $e');
    }
  }

  Future<void> _excluir() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<RecursosProvider>();
      final ok = await provider.excluirRecurso(widget.recurso!.id!);
      if (!mounted) return;
      if (!ok) throw provider.error ?? 'erro desconhecido';
      Navigator.pop(context);
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

/// Projetos que usam o recurso (busca ao abrir os detalhes).
class _ProjetosDoRecurso extends StatelessWidget {
  const _ProjetosDoRecurso({required this.recursoId});
  final int recursoId;

  @override
  Widget build(BuildContext context) {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: RecursosService.instance.projetosDoRecurso(recursoId),
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
                child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: StyleProjetos.laranja))),
          );
        }
        if (s.hasError) {
          return Text('Não foi possível carregar os projetos.',
              style: fonteIdv(tamanho: 13, cor: CoresIdv.vermelho));
        }
        final projetos = s.data ?? const [];
        if (projetos.isEmpty) {
          return Text('Ainda não está em nenhum projeto.',
              style: fonteIdv(tamanho: 13, cor: CoresIdv.textoSecundario));
        }
        return Column(
          children: [
            for (final p in projetos)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: CoresIdv.campo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CoresIdv.borda),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_rounded,
                        size: 18, color: StyleProjetos.azulEscuro),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${p['nome_projeto'] ?? 'Projeto'}',
                          style: fonteIdv(peso: FontWeight.w600)),
                    ),
                    Text(
                      p['custo_hora'] == null
                          ? 'sem valor'
                          : _preco(p, moeda),
                      style: fonteIdv(tamanho: 13, cor: CoresIdv.textoSecundario),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "2 × R\$ 35,00/mês" a partir da linha de /recursos/:id/projetos
/// (quantidade e tipo_cobranca só vêm depois da mudança no back-end).
String _preco(Map<String, dynamic> p, NumberFormat moeda) {
  final cobranca = CobrancaRecurso.de(p['tipo_cobranca']);
  final quantidade = int.tryParse('${p['quantidade'] ?? 1}') ?? 1;
  final preco = '${moeda.format(double.tryParse('${p['custo_hora']}') ?? 0)}'
      '${cobranca.sufixo}';
  return quantidade > 1 ? '$quantidade × $preco' : preco;
}
