import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/models/projeto.dart';
import 'package:fabrica_software_app/models/recurso.dart';
import 'package:fabrica_software_app/models/recurso_projeto.dart';
import 'package:fabrica_software_app/providers/recursos_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Recursos/components/Recursos_modal.dart';
import 'package:fabrica_software_app/services/recurso_projeto_service.dart';
import 'package:fabrica_software_app/services/recursos_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// =====================================================================
// Recursos de um projeto. O recurso é do cadastro geral (menu "Gestão de
// recursos"); aqui o projeto só o vincula, com o custo/hora e o período
// de uso dele neste projeto. É desse vínculo que saem os custos dos
// relatórios.
// =====================================================================

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _data = DateFormat('dd/MM/yyyy');

/// Custo estimado do vínculo (quantidade e cobrança: ver
/// [RecursoProjeto.custoEstimado]).
double custoDoVinculo(RecursoProjeto v) => v.custoEstimado();

/// "2 × R\$ 35,00/mês" (sem o "1 ×" quando é uma unidade).
String precoDoVinculo(RecursoProjeto v) {
  final preco = '${_moeda.format(v.custoHora ?? 0)}${v.cobranca.sufixo}';
  return v.quantidade > 1 ? '${v.quantidade} × $preco' : preco;
}

Future<void> abrirRecursosDoProjeto(BuildContext context, Projeto projeto) {
  return mostrarDialogo(
    context: context,
    builder: (_) => _RecursosDoProjeto(projeto: projeto),
  );
}

class _RecursosDoProjeto extends StatefulWidget {
  const _RecursosDoProjeto({required this.projeto});
  final Projeto projeto;

  @override
  State<_RecursosDoProjeto> createState() => _RecursosDoProjetoState();
}

class _RecursosDoProjetoState extends State<_RecursosDoProjeto> {
  final _vinculosService = RecursoProjetoService();
  bool _carregando = true;
  String? _erro;
  List<Recurso> _recursos = [];
  List<RecursoProjeto> _vinculos = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final r = await Future.wait([
        RecursosService.instance.listarRecursos(),
        _vinculosService.getRecursosProjeto(),
      ]);
      _recursos = r[0] as List<Recurso>;
      _vinculos = (r[1] as List<RecursoProjeto>)
          .where((v) => v.projetoId == widget.projeto.id)
          .toList();
    } catch (e) {
      _erro = e.toString();
    }
    if (mounted) setState(() => _carregando = false);
  }

  Recurso? _recurso(int id) {
    for (final r in _recursos) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> _vincular({RecursoProjeto? editar}) async {
    final ok = await mostrarDialogo<bool>(
      context: context,
      barrierDismissible: false,
      // O RecursosProvider é global (main.dart): não precisa repassar.
      builder: (_) => _PainelVinculo(
        projeto: widget.projeto,
        recursos: _recursos,
        jaVinculados: {for (final v in _vinculos) v.recursoId},
        editar: editar,
      ),
    );
    if (ok == true) {
      await _carregar();
      // A lista geral (contagem de projetos) também muda.
      if (mounted) context.read<RecursosProvider>().carregarRecursos();
    }
  }

  Future<void> _desvincular(RecursoProjeto v) async {
    final nome = _recurso(v.recursoId)?.nome ?? 'O recurso';
    final ok = await mostrarDialogo<bool>(
      context: context,
      builder: (ctx) => _ConfirmarDesvincular(
        nome: nome,
        projeto: widget.projeto.nomeProjeto,
        aoConfirmar: () =>
            _vinculosService.deleteRecursoProjeto(v.recursoId, v.projetoId),
      ),
    );
    if (ok == true) {
      await _carregar();
      if (mounted) context.read<RecursosProvider>().carregarRecursos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _vinculos.fold<double>(0, (s, v) => s + custoDoVinculo(v));

    return PainelIdv(
      titulo: 'Recursos do projeto',
      ajuda: 'Os recursos são cadastrados em "Gestão de recursos", no menu. '
          'Aqui você escolhe quais este projeto usa e quanto custam por hora '
          'nele; o custo aparece nos relatórios.',
      largura: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.projeto.nomeProjeto,
                        style: fonteIdv(tamanho: 16, peso: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      _vinculos.isEmpty
                          ? 'Nenhum recurso vinculado'
                          : '${_vinculos.length} ${_vinculos.length == 1 ? 'recurso' : 'recursos'} · '
                              'custo estimado ${_moeda.format(total)}',
                      style: fonteIdv(tamanho: 13, cor: CoresIdv.textoSecundario),
                    ),
                  ],
                ),
              ),
              BotaoPrincipalIdv(
                rotulo: 'Vincular recurso',
                aoTocar: _carregando || _erro != null ? null : () => _vincular(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_carregando)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                  child: CircularProgressIndicator(color: StyleProjetos.laranja)),
            )
          else if (_erro != null)
            Column(children: [
              Text('Não foi possível carregar os recursos: $_erro',
                  style: fonteIdv(cor: CoresIdv.vermelho)),
              TextButton(onPressed: _carregar, child: const Text('Tentar de novo')),
            ])
          else if (_vinculos.isEmpty)
            _Vazio(aoVincular: () => _vincular())
          else
            for (final v in _vinculos)
              _LinhaVinculo(
                vinculo: v,
                recurso: _recurso(v.recursoId),
                aoEditar: () => _vincular(editar: v),
                aoDesvincular: () => _desvincular(v),
              ),
        ],
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.aoVincular});
  final VoidCallback aoVincular;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CoresIdv.borda),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 30, color: CoresIdv.textoSecundario),
          const SizedBox(height: 10),
          Text('Este projeto ainda não usa nenhum recurso',
              style: fonteIdv(peso: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Vincule um recurso já cadastrado ou cadastre um novo.',
              textAlign: TextAlign.center,
              style: fonteIdv(tamanho: 13, cor: CoresIdv.textoSecundario)),
          const SizedBox(height: 14),
          BotaoSecundarioIdv(
              rotulo: 'Vincular recurso',
              icone: Icons.add_link_rounded,
              aoTocar: aoVincular),
        ],
      ),
    );
  }
}

class _LinhaVinculo extends StatelessWidget {
  const _LinhaVinculo({
    required this.vinculo,
    required this.recurso,
    required this.aoEditar,
    required this.aoDesvincular,
  });

  final RecursoProjeto vinculo;
  final Recurso? recurso;
  final VoidCallback aoEditar;
  final VoidCallback aoDesvincular;

  @override
  Widget build(BuildContext context) {
    final v = vinculo;
    final periodo = '${_data.format(v.dataAlocacao)} a '
        '${v.dataDesalocacao == null ? 'em aberto' : _data.format(v.dataDesalocacao!)}';
    final semCusto = (v.custoHora ?? 0) == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: CoresIdv.campo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CoresIdv.borda),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: StyleProjetos.azulEscuro, shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_rounded,
                size: 19, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recurso?.nome ?? 'Recurso ${v.recursoId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: fonteIdv(peso: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${recurso?.tipo ?? ''} · $periodo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: fonteIdv(tamanho: 12.5, cor: CoresIdv.textoSecundario)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                semCusto ? 'Sem valor' : precoDoVinculo(v),
                style: fonteIdv(
                    tamanho: 13,
                    peso: FontWeight.w600,
                    cor: semCusto ? StyleProjetos.laranja : CoresIdv.texto),
              ),
              const SizedBox(height: 2),
              Text(
                semCusto ? 'Informe para calcular' : _moeda.format(custoDoVinculo(v)),
                style: fonteIdv(tamanho: 12, cor: CoresIdv.textoSecundario),
              ),
            ],
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Editar custo e período',
            onPressed: aoEditar,
            icon: const Icon(FontAwesomeIcons.penToSquare,
                size: 15, color: StyleProjetos.azulEscuro),
          ),
          IconButton(
            tooltip: 'Desvincular do projeto',
            onPressed: aoDesvincular,
            icon: const Icon(Icons.link_off_rounded,
                size: 19, color: CoresIdv.vermelho),
          ),
        ],
      ),
    );
  }
}

/// Vincular um recurso (ou editar o vínculo): qual recurso, custo/hora e
/// período. Dá para cadastrar um recurso novo sem sair daqui.
class _PainelVinculo extends StatefulWidget {
  const _PainelVinculo({
    required this.projeto,
    required this.recursos,
    required this.jaVinculados,
    this.editar,
  });

  final Projeto projeto;
  final List<Recurso> recursos;
  final Set<int> jaVinculados;
  final RecursoProjeto? editar;

  @override
  State<_PainelVinculo> createState() => _PainelVinculoState();
}

class _PainelVinculoState extends State<_PainelVinculo> {
  late List<Recurso> _recursos = [...widget.recursos];
  Recurso? _escolhido;
  final _custo = TextEditingController();
  final _quantidade = TextEditingController(text: '1');
  CobrancaRecurso _cobranca = CobrancaRecurso.hora;
  DateTime? _inicio;
  DateTime? _fim;
  bool _salvando = false;

  bool get _editando => widget.editar != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    if (e != null) {
      _escolhido = _recursos.where((r) => r.id == e.recursoId).firstOrNull;
      if ((e.custoHora ?? 0) > 0) _custo.text = formatarMoedaBr(e.custoHora!);
      _quantidade.text = '${e.quantidade}';
      _cobranca = e.cobranca;
      _inicio = e.dataAlocacao;
      _fim = e.dataDesalocacao;
    } else {
      // Por padrão, o período do projeto.
      _inicio = widget.projeto.dataInicio ?? DateTime.now();
      _fim = widget.projeto.dataFinalPrevisto;
    }
  }

  @override
  void dispose() {
    _custo.dispose();
    _quantidade.dispose();
    super.dispose();
  }

  List<Recurso> get _disponiveis => _recursos
      .where((r) => !widget.jaVinculados.contains(r.id) || r.id == _escolhido?.id)
      .toList();

  Future<void> _cadastrarNovo() async {
    final provider = context.read<RecursosProvider>();
    provider.ultimoCriado = null;
    await mostrarDialogo(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RecursoModal(mode: RecursoModalMode.create),
    );
    final novo = provider.ultimoCriado;
    if (novo != null && mounted) {
      setState(() {
        _recursos = [..._recursos, novo];
        _escolhido = novo;
      });
    }
  }

  Future<void> _salvar() async {
    if (_escolhido?.id == null) {
      avisar(context, 'Escolha o recurso que o projeto vai usar.', tipo: TipoAviso.info);
      return;
    }
    if (_inicio == null) {
      avisar(context, 'Informe quando o recurso começa a ser usado.', tipo: TipoAviso.info);
      return;
    }
    setState(() => _salvando = true);
    final vinculo = RecursoProjeto(
      recursoId: _escolhido!.id!,
      projetoId: widget.projeto.id!,
      custoHora: lerMoedaBr(_custo.text) ?? 0,
      dataAlocacao: _inicio!,
      dataDesalocacao: _fim,
      quantidade: (int.tryParse(_quantidade.text) ?? 1).clamp(1, 1000000),
      cobranca: _cobranca,
    );
    try {
      final service = RecursoProjetoService();
      if (_editando) {
        await service.updateRecursoProjeto(vinculo);
      } else {
        await service.createRecursoProjeto(vinculo);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      avisarApp(_editando ? 'Vínculo atualizado.' : '${_escolhido!.nome} vinculado ao projeto.',
          tipo: TipoAviso.sucesso);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      avisar(context, 'Não foi possível salvar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PainelIdv(
      titulo: _editando ? 'Editar vínculo' : 'Vincular recurso',
      // Três botões no rodapé ao vincular: precisa de mais largura.
      largura: 640,
      rotuloAcao: _editando ? 'Salvar alterações' : 'Vincular ao projeto',
      carregando: _salvando,
      aoConfirmar: _salvar,
      acoesExtras: [
        if (!_editando)
          TextButton.icon(
            onPressed: _salvando ? null : _cadastrarNovo,
            icon: const Icon(Icons.add_rounded, size: 18, color: StyleProjetos.laranja),
            label: Text('Cadastrar novo recurso',
                style: fonteIdv(peso: FontWeight.w600, cor: StyleProjetos.laranja)),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SecaoIdv('Recurso'),
          if (_editando)
            CampoIdv(
              rotulo: 'Recurso',
              valorInicial: _escolhido?.nome ?? 'Recurso ${widget.editar!.recursoId}',
              somenteLeitura: true,
            )
          else
            BuscaSelecaoIdv(
              unico: true,
              listarSemBusca: true,
              itens: _disponiveis,
              rotulo: (r) => (r as Recurso).nome,
              detalhe: (r) {
                final rec = r as Recurso;
                return rec.disponivel ? rec.tipo : '${rec.tipo} · indisponível';
              },
              hintBusca: 'Pesquisar recurso ou tipo',
              textoVazio: 'Todos os recursos já estão neste projeto. '
                  'Cadastre um novo pelo botão abaixo.',
              textoNenhumSelecionado: 'Nenhum recurso escolhido.',
              marcado: (r) => (r as Recurso).id == _escolhido?.id,
              aoAlternar: (r) => setState(() =>
                  _escolhido = (r as Recurso).id == _escolhido?.id ? null : r),
            ),
          const SizedBox(height: 10),
          const SecaoIdv('Uso neste projeto',
              descricao: 'Quantidade e valor podem ser diferentes em cada '
                  'projeto (ex.: 2 planos para uma equipe de 40 pessoas).'),
          const RotuloIdv('Como é cobrado'),
          OpcoesIdv<CobrancaRecurso>(
            opcoes: CobrancaRecurso.values,
            valor: _cobranca,
            rotulo: (c) => c.rotulo,
            aoMudar: (c) => setState(() => _cobranca = c),
          ),
          const SizedBox(height: 18),
          LinhaCamposIdv(children: [
            CampoIdv(
              rotulo: 'Quantidade',
              controle: _quantidade,
              teclado: TextInputType.number,
              formatadores: [FilteringTextInputFormatter.digitsOnly],
              aoMudar: (_) => setState(() {}),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RotuloIdv(switch (_cobranca) {
                    CobrancaRecurso.hora => 'Valor por hora (cada)',
                    CobrancaRecurso.mes => 'Valor por mês (cada)',
                    CobrancaRecurso.unico => 'Valor (cada)',
                  }),
                  TextField(
                    controller: _custo,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FormatoMoedaBr()],
                    onChanged: (_) => setState(() {}),
                    style: fonteIdv(),
                    decoration: decoracaoCampoIdv(dica: 'R\$ 0,00'),
                  ),
                ],
              ),
            ),
          ]),
          const RotuloIdv('Período de uso', obrigatorio: true),
          PeriodoIdv(
            inicio: _inicio,
            fim: _fim,
            aoMudar: (i, f) => setState(() {
              _inicio = i;
              _fim = f;
            }),
          ),
          const SizedBox(height: 16),
          _Estimativa(
            texto: _estimativa(),
          ),
        ],
      ),
    );
  }

  /// Custo do vínculo com o que está preenchido agora.
  String _estimativa() {
    final valor = lerMoedaBr(_custo.text) ?? 0;
    if (valor <= 0 || _inicio == null) {
      return 'Informe o valor para ver o custo estimado no projeto.';
    }
    final v = RecursoProjeto(
      recursoId: 0,
      projetoId: 0,
      custoHora: valor,
      dataAlocacao: _inicio!,
      dataDesalocacao: _fim,
      quantidade: (int.tryParse(_quantidade.text) ?? 1).clamp(1, 1000000),
      cobranca: _cobranca,
    );
    final conta = switch (_cobranca) {
      CobrancaRecurso.hora => _fim == null
          ? 'dias até hoje × 8 h'
          : 'dias do período × 8 h',
      CobrancaRecurso.mes => 'meses do período',
      CobrancaRecurso.unico => 'pago uma vez',
    };
    return 'Custo estimado: ${_moeda.format(v.custoEstimado())} '
        '(${precoDoVinculo(v)}, $conta)';
  }
}

/// Faixa com o custo estimado do vínculo que está sendo preenchido.
class _Estimativa extends StatelessWidget {
  const _Estimativa({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CoresIdv.laranjaSuave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_outlined,
              size: 19, color: StyleProjetos.laranja),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: fonteIdv(tamanho: 13, peso: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _ConfirmarDesvincular extends StatefulWidget {
  const _ConfirmarDesvincular(
      {required this.nome, required this.projeto, required this.aoConfirmar});
  final String nome;
  final String projeto;
  final Future<void> Function() aoConfirmar;

  @override
  State<_ConfirmarDesvincular> createState() => _ConfirmarDesvincularState();
}

class _ConfirmarDesvincularState extends State<_ConfirmarDesvincular> {
  bool _carregando = false;

  Future<void> _confirmar() async {
    setState(() => _carregando = true);
    try {
      await widget.aoConfirmar();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      avisar(context, 'Não foi possível desvincular: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConfirmacaoIdv(
      titulo: 'Desvincular recurso',
      mensagem: '${widget.nome} sai do projeto "${widget.projeto}". O recurso '
          'continua no cadastro e pode ser vinculado de novo.',
      rotuloAcao: 'Desvincular',
      carregando: _carregando,
      aoConfirmar: _confirmar,
    );
  }
}
