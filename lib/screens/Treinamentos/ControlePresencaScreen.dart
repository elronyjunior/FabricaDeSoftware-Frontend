import 'package:fabrica_software_app/Widgets/Barra_lateral/Barra_Lateral.dart';
import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/providers/controle_presenca_provider.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/components/escala_design.dart';
import 'package:fabrica_software_app/screens/Relatorio/components/pecas_relatorio.dart';
import 'package:fabrica_software_app/screens/Treinamentos/importar_participantes.dart';
import 'package:fabrica_software_app/services/arquivo/escolher_arquivo.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// =====================================================================
// Controle de presença no modelo do Visualizar projeto: indicadores no
// topo e a lista de presença em cartão, um dia de cada vez (os dias ficam
// em pílulas que quebram linha, sem rolagem lateral).
// =====================================================================

const _vermelho = Color(0xFFD62A1E);
const _verde = Color(0xFF2E8B57);

class ControlePresencaScreen extends StatefulWidget {
  final int treinamentoId;
  final String tituloTreinamento;

  const ControlePresencaScreen(
      {super.key,
      required this.treinamentoId,
      required this.tituloTreinamento});

  @override
  State<ControlePresencaScreen> createState() => _ControlePresencaScreenState();
}

class _ControlePresencaScreenState extends State<ControlePresencaScreen> {
  late final ControlePresencaProvider _provider = ControlePresencaProvider()
    ..carregarDados(widget.treinamentoId);

  /// Dia mostrado na lista (índice em headersDias). Null = escolher o padrão
  /// (hoje, se existir; senão o último) assim que os dados chegarem.
  int? _dia;

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  /// "Dia 1 (23/11)" → "23/11".
  static String rotuloDia(String header) =>
      header.split('(').last.replaceAll(')', '').trim();

  int? _diaAtual(ControlePresencaProvider p) {
    final dias = p.headersDias;
    if (dias.isEmpty) return null;
    if (_dia != null && _dia! < dias.length) return _dia;
    final hoje = DateFormat('dd/MM').format(DateTime.now());
    final i = dias.indexWhere((d) => rotuloDia(d) == hoje);
    return i >= 0 ? i : dias.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final desktop = LayoutPrincipal.menuFixo(context);
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<ControlePresencaProvider>(
        builder: (context, provider, _) => PopScope(
          // Ao sair com marcações ainda não enviadas, salva antes; só pede
          // confirmação se o salvamento falhar.
          canPop: !provider.temMudancasPendentes && !provider.isSaving,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final salvou = await provider.salvarAlteracoes();
            if (!context.mounted) return;
            final sair =
                salvou ? true : await _confirmarSaidaSemSalvar(context);
            if (sair == true && context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            drawer: BarraLateral.drawer(context),
            backgroundColor: desktop ? Colors.transparent : null,
            body: DecoratedBox(
              decoration: desktop
                  ? const BoxDecoration()
                  : const BoxDecoration(gradient: StyleProjetos.gradienteFundo),
              child: SafeArea(
                child: desktop
                    ? EscalaDesign(
                        larguraBase: LayoutPrincipal.larguraBase -
                            LayoutPrincipal.recuoConteudo,
                        child: _conteudo(provider, true),
                      )
                    : _conteudo(provider, false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _conteudo(ControlePresencaProvider p, bool desktop) {
    return SingleChildScrollView(
      padding: desktop
          ? const EdgeInsets.fromLTRB(25, 48, 36, 32)
          : const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cabecalho(
            titulo: widget.tituloTreinamento,
            desktop: desktop,
            direita: p.isLoading || p.error != null
                ? null
                : _StatusSalvamento(
                    salvando: p.isSaving || p.temMudancasPendentes,
                    erro: p.erroSalvar,
                    salvoEm: p.salvoEm,
                    aoTentarDeNovo: () => p.salvarAlteracoes(),
                  ),
          ),
          SizedBox(height: desktop ? 36 : 20),
          if (p.isLoading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                  child: CircularProgressIndicator(color: CoresIdv.laranja)),
            )
          else if (p.error != null)
            CartaoRelatorio(
              titulo: 'Não foi possível carregar a lista',
              subtitulo: p.error,
              acao: BotaoSecundarioIdv(
                rotulo: 'Tentar novamente',
                icone: FontAwesomeIcons.rotateRight,
                aoTocar: () => p.carregarDados(widget.treinamentoId),
              ),
              child: const SizedBox.shrink(),
            )
          else ...[
            _indicadores(p, desktop),
            const SizedBox(height: 22),
            _lista(p, desktop),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Indicadores

  Widget _indicadores(ControlePresencaProvider p, bool desktop) {
    var presencas = 0, faltas = 0;
    for (final a in p.alunos) {
      for (final v in (a['presencas'] as Map).values) {
        if (v == 'P') presencas++;
        if (v == 'F') faltas++;
      }
    }
    final marcadas = presencas + faltas;
    final taxa = marcadas == 0 ? 0 : (presencas / marcadas * 100).round();
    final dias = p.headersDias.length;

    final itens = [
      IndicadorRelatorio(
        icone: FontAwesomeIcons.chartPie,
        titulo: 'Taxa de presença',
        valor: '$taxa',
        complemento: '%',
        detalhe: '$marcadas ${marcadas == 1 ? 'marcação' : 'marcações'}',
        destaque: true,
      ),
      IndicadorRelatorio(
        icone: FontAwesomeIcons.circleCheck,
        titulo: 'Presenças',
        valor: '$presencas',
        detalhe: 'Somando todos os dias',
      ),
      IndicadorRelatorio(
        icone: FontAwesomeIcons.circleXmark,
        titulo: 'Faltas',
        valor: '$faltas',
        detalhe: 'Somando todos os dias',
      ),
      IndicadorRelatorio(
        icone: FontAwesomeIcons.users,
        titulo: 'Participantes',
        valor: '${p.alunos.length}',
        detalhe: '$dias ${dias == 1 ? 'dia de aula' : 'dias de aula'}',
      ),
    ];

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final k in itens) ...[k, const SizedBox(height: 12)]
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < itens.length; i++) ...[
          if (i > 0) const SizedBox(width: 18),
          Expanded(child: itens[i]),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------ Lista

  Widget _lista(ControlePresencaProvider p, bool desktop) {
    final dia = _diaAtual(p);
    final n = p.alunos.length;
    final acoes = [
      BotaoSecundarioIdv(
        rotulo: 'Importar lista',
        icone: FontAwesomeIcons.fileImport,
        aoTocar: p.ocupado ? null : () => _importarLista(p),
      ),
      BotaoSecundarioIdv(
        rotulo: 'Novo participante',
        icone: FontAwesomeIcons.userPlus,
        aoTocar: p.ocupado ? null : () => _novoParticipante(p),
      ),
    ];

    return CartaoRelatorio(
      titulo: 'Lista de presença',
      subtitulo: '$n ${n == 1 ? 'participante' : 'participantes'}',
      acao: desktop
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              acoes[0],
              const SizedBox(width: 10),
              acoes[1],
            ])
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!desktop) ...[
            Wrap(spacing: 10, runSpacing: 10, children: acoes),
            const SizedBox(height: 18),
          ],
          if (p.ocupado) ...[
            _Andamento(p.andamento ?? 'Atualizando…'),
            const SizedBox(height: 14),
          ],
          IgnorePointer(
            ignoring: p.ocupado,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: p.ocupado ? 0.55 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SeletorDias(
                    dias: [for (final d in p.headersDias) rotuloDia(d)],
                    atual: dia,
                    aoEscolher: (i) => setState(() => _dia = i),
                    aoAdicionar: () => _adicionarDia(p),
                  ),
                  const SizedBox(height: 14),
                  if (dia != null && n > 0) ...[
                    _BarraDoDia(
                      dia: rotuloDia(p.headersDias[dia]),
                      aoMarcarTodos: (s) => p.marcarTodos(dia, s),
                      aoRemover: () => _confirmarExclusaoDia(p, dia),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TabelaRelatorio(
                    colunas: [
                      'Participante',
                      'Frequência',
                      dia == null
                          ? 'Presença'
                          : 'Presença em ${rotuloDia(p.headersDias[dia])}',
                      '',
                    ],
                    pesos: desktop ? const [4, 2, 3, 1] : const [4, 3, 4, 1],
                    vazio:
                        'Nenhum participante. Use "Novo participante" ou "Importar lista".',
                    linhas: [
                      for (final a in p.alunos) _linha(p, a, dia, desktop),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _linha(
      ControlePresencaProvider p, dynamic aluno, int? dia, bool desktop) {
    var pres = 0, marc = 0;
    for (final v in (aluno['presencas'] as Map).values) {
      if (v == 'P') pres++;
      if (v == 'P' || v == 'F') marc++;
    }
    final nome = (aluno['nome'] ?? '').toString();
    final email = (aluno['email'] ?? '').toString();
    return [
      Row(children: [
        _Avatar(nome),
        const SizedBox(width: 12),
        Expanded(
          child: CelulaRelatorio(nome,
              abaixo: email.isEmpty ? null : email, forte: true),
        ),
      ]),
      _Frequencia(presencas: pres, marcadas: marc),
      dia == null
          ? CelulaRelatorio('Adicione um dia')
          : _MarcarPresenca(
              status: (aluno['presencas'][p.headersDias[dia]] ?? '').toString(),
              compacto: !desktop,
              aoMudar: (s) => p.setPresenca(aluno['rowIndex'], dia, s),
            ),
      Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          tooltip: 'Remover participante',
          visualDensity: VisualDensity.compact,
          onPressed: () => _confirmarExclusaoAluno(p, aluno),
          icon: const FaIcon(FontAwesomeIcons.trashCan,
              size: 16, color: _vermelho),
        ),
      ),
    ];
  }

  // ------------------------------------------------------------------ Ações

  void _avisarResultado(ControlePresencaProvider p, bool ok, String sucesso) {
    if (!mounted) return;
    if (ok) {
      avisarApp(sucesso, tipo: TipoAviso.sucesso);
    } else {
      avisarApp(p.ultimoErro ?? 'Não foi possível concluir a ação.');
    }
  }

  Future<bool?> _confirmarSaidaSemSalvar(BuildContext context) {
    return mostrarDialogo<bool>(
      context: context,
      builder: (ctx) => ConfirmacaoIdv(
        titulo: 'Sair sem salvar?',
        mensagem:
            'Não foi possível salvar as últimas presenças marcadas. Se sair agora, elas serão perdidas.',
        rotuloAcao: 'Sair sem salvar',
        aoConfirmar: () => Navigator.pop(ctx, true),
      ),
    );
  }

  Future<void> _adicionarDia(ControlePresencaProvider p) async {
    final existentes = {for (final d in p.headersDias) rotuloDia(d)};
    final escolhido = await mostrarDialogo<DateTime>(
      context: context,
      builder: (_) => _PainelNovoDia(existentes: existentes),
    );
    if (escolhido == null || !mounted) return;
    final rotulo = DateFormat('dd/MM').format(escolhido);
    final ok = await p.adicionarDia(widget.treinamentoId, rotulo);
    if (ok && mounted) {
      final i = p.headersDias.indexWhere((d) => rotuloDia(d) == rotulo);
      setState(() => _dia = i >= 0 ? i : p.headersDias.length - 1);
    }
    _avisarResultado(p, ok, 'Dia $rotulo adicionado.');
  }

  Future<void> _novoParticipante(ControlePresencaProvider p) async {
    final dados = await mostrarDialogo<({String nome, String email})>(
      context: context,
      builder: (_) => const _PainelNovoParticipante(),
    );
    if (dados == null || !mounted) return;
    final ok =
        await p.adicionarAluno(widget.treinamentoId, dados.nome, dados.email);
    _avisarResultado(p, ok, 'Participante adicionado.');
  }

  Future<void> _importarLista(ControlePresencaProvider p) async {
    final ja = {
      for (final a in p.alunos)
        chaveParticipante(
            (a['nome'] ?? '').toString(), (a['email'] ?? '').toString()),
    };
    final novos = await mostrarDialogo<List<ParticipanteImportado>>(
      context: context,
      builder: (_) => _PainelImportar(jaNaLista: ja),
    );
    if (novos == null || novos.isEmpty || !mounted) return;
    final falhas = await p.adicionarAlunos(
      widget.treinamentoId,
      [for (final n in novos) (nome: n.nome, email: n.email)],
    );
    if (!mounted) return;
    if (falhas == 0) {
      avisarApp(
          novos.length == 1
              ? '1 participante adicionado.'
              : '${novos.length} participantes adicionados.',
          tipo: TipoAviso.sucesso);
    } else {
      avisarApp(p.ultimoErro ?? 'Não foi possível adicionar os participantes.');
    }
  }

  void _confirmarExclusaoDia(ControlePresencaProvider p, int index) {
    final rotulo = rotuloDia(p.headersDias[index]);
    mostrarDialogo(
      context: context,
      builder: (ctx) => ConfirmacaoIdv(
        titulo: 'Remover dia',
        mensagem:
            'O dia $rotulo e as presenças marcadas nele serão removidos. Essa ação não pode ser desfeita.',
        rotuloAcao: 'Remover dia',
        aoConfirmar: () async {
          Navigator.pop(ctx);
          final ok = await p.removerDia(widget.treinamentoId, index);
          if (ok && mounted) setState(() => _dia = null);
          _avisarResultado(p, ok, 'Dia removido.');
        },
      ),
    );
  }

  void _confirmarExclusaoAluno(ControlePresencaProvider p, dynamic aluno) {
    mostrarDialogo(
      context: context,
      builder: (ctx) => ConfirmacaoIdv(
        titulo: 'Remover participante',
        mensagem:
            '${aluno['nome']} e as presenças dele serão removidos. Essa ação não pode ser desfeita.',
        rotuloAcao: 'Remover participante',
        aoConfirmar: () async {
          Navigator.pop(ctx);
          final ok =
              await p.removerAluno(widget.treinamentoId, aluno['rowIndex']);
          _avisarResultado(p, ok, 'Participante removido.');
        },
      ),
    );
  }
}

// =====================================================================
// Peças da tela
// =====================================================================

/// Voltar, nome do treinamento e, à direita, o estado do salvamento.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.titulo,
    required this.desktop,
    this.direita,
  });

  final String titulo;
  final bool desktop;
  final Widget? direita;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: desktop ? 6 : 0, right: 10),
          child: IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(FontAwesomeIcons.arrowLeft,
                color: StyleProjetos.azulEscuro),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: desktop
                    ? StyleProjetos.titulo
                    : StyleProjetos.titulo.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text('Controle de presença', style: StyleProjetos.cardCliente),
            ],
          ),
        ),
        if (direita != null)
          Padding(
            padding: EdgeInsets.only(top: desktop ? 18 : 6, left: 12),
            child: direita,
          ),
      ],
    );
  }
}

/// A chamada é salva sozinha: aqui só aparece se está salvando, se salvou
/// ou se deu erro (com "Tentar de novo").
class _StatusSalvamento extends StatelessWidget {
  const _StatusSalvamento({
    required this.salvando,
    required this.erro,
    required this.salvoEm,
    required this.aoTentarDeNovo,
  });

  final bool salvando;
  final String? erro;
  final DateTime? salvoEm;
  final VoidCallback aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final Widget icone;
    final String texto;
    var cor = StyleProjetos.textoSecundario;
    final comErro = erro != null && !salvando;
    if (comErro) {
      icone = const FaIcon(FontAwesomeIcons.circleExclamation,
          size: 13, color: _vermelho);
      texto = 'Não foi possível salvar';
      cor = _vermelho;
    } else if (salvando) {
      icone = const SizedBox(
        width: 13,
        height: 13,
        child:
            CircularProgressIndicator(strokeWidth: 2, color: CoresIdv.laranja),
      );
      texto = 'Salvando…';
    } else if (salvoEm != null) {
      icone =
          const FaIcon(FontAwesomeIcons.circleCheck, size: 13, color: _verde);
      texto = 'Salvo às ${DateFormat('HH:mm').format(salvoEm!)}';
    } else {
      icone = const FaIcon(FontAwesomeIcons.cloud,
          size: 13, color: StyleProjetos.textoSecundario);
      texto = 'Salvamento automático';
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      icone,
      const SizedBox(width: 8),
      Text(texto,
          style: fonteIdv(tamanho: 13, peso: FontWeight.w500, cor: cor)),
      if (comErro) ...[
        const SizedBox(width: 6),
        TextButton(
          onPressed: aoTentarDeNovo,
          style: TextButton.styleFrom(
            foregroundColor: StyleProjetos.laranja,
            visualDensity: VisualDensity.compact,
            textStyle: fonteIdv(tamanho: 13, peso: FontWeight.w600),
          ),
          child: const Text('Tentar de novo'),
        ),
      ],
    ]);
  }
}

/// Barra fina de andamento ("Adicionando 3 de 15…") em cima da lista.
class _Andamento extends StatelessWidget {
  const _Andamento(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: CoresIdv.laranjaSuave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto,
              style: fonteIdv(
                  tamanho: 12.5,
                  peso: FontWeight.w600,
                  cor: StyleProjetos.texto)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              minHeight: 4,
              color: CoresIdv.laranja,
              backgroundColor: Color(0x33FF5F00),
            ),
          ),
        ],
      ),
    );
  }
}

/// Os dias de aula em pílulas (quebram linha) e o "Adicionar dia".
class _SeletorDias extends StatelessWidget {
  const _SeletorDias({
    required this.dias,
    required this.atual,
    required this.aoEscolher,
    required this.aoAdicionar,
  });

  final List<String> dias;
  final int? atual;
  final ValueChanged<int> aoEscolher;
  final VoidCallback aoAdicionar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text('Dias de aula',
              style: fonteIdv(
                  tamanho: 12.5,
                  peso: FontWeight.w600,
                  cor: CoresIdv.textoSecundario)),
        ),
        for (var i = 0; i < dias.length; i++)
          _Pilula(
            texto: dias[i],
            selecionada: i == atual,
            aoTocar: () => aoEscolher(i),
          ),
        _Pilula(
          texto: 'Adicionar dia',
          icone: FontAwesomeIcons.plus,
          destaque: true,
          aoTocar: aoAdicionar,
        ),
      ],
    );
  }
}

class _Pilula extends StatelessWidget {
  const _Pilula({
    required this.texto,
    required this.aoTocar,
    this.selecionada = false,
    this.destaque = false,
    this.icone,
  });

  final String texto;
  final VoidCallback aoTocar;
  final bool selecionada;
  final bool destaque;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final cor = selecionada
        ? Colors.white
        : destaque
            ? StyleProjetos.laranja
            : StyleProjetos.texto;
    return Material(
      color: selecionada
          ? StyleProjetos.azulEscuro
          : destaque
              ? CoresIdv.laranjaSuave
              : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selecionada
              ? StyleProjetos.azulEscuro
              : destaque
                  ? Colors.transparent
                  : const Color(0x330F1030),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icone != null) ...[
              FaIcon(icone, size: 11, color: cor),
              const SizedBox(width: 6),
            ],
            Text(texto,
                style: fonteIdv(tamanho: 13, peso: FontWeight.w600, cor: cor)),
          ]),
        ),
      ),
    );
  }
}

/// "Marcar todos" e "Remover dia" do dia escolhido.
class _BarraDoDia extends StatelessWidget {
  const _BarraDoDia({
    required this.dia,
    required this.aoMarcarTodos,
    required this.aoRemover,
  });

  final String dia;
  final ValueChanged<String> aoMarcarTodos;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    Widget link(
            String texto, IconData icone, Color cor, VoidCallback aoTocar) =>
        TextButton.icon(
          onPressed: aoTocar,
          style: TextButton.styleFrom(
            foregroundColor: cor,
            visualDensity: VisualDensity.compact,
            textStyle: fonteIdv(tamanho: 12.5, peso: FontWeight.w600),
          ),
          icon: FaIcon(icone, size: 12, color: cor),
          label: Text(texto),
        );

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        link('Todos presentes', FontAwesomeIcons.circleCheck, _verde,
            () => aoMarcarTodos('P')),
        link('Todos com falta', FontAwesomeIcons.circleXmark, _vermelho,
            () => aoMarcarTodos('F')),
        link('Limpar $dia', FontAwesomeIcons.eraser,
            StyleProjetos.textoSecundario, () => aoMarcarTodos('')),
        link('Remover dia', FontAwesomeIcons.trashCan, _vermelho, aoRemover),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.nome);
  final String nome;

  @override
  Widget build(BuildContext context) {
    final partes = nome.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    final iniciais = partes.isEmpty
        ? '?'
        : (partes.first[0] + (partes.length > 1 ? partes.last[0] : ''))
            .toUpperCase();
    return CircleAvatar(
      radius: 16,
      backgroundColor: StyleProjetos.azulEscuro,
      child: Text(iniciais,
          style:
              fonteIdv(tamanho: 12, peso: FontWeight.w600, cor: Colors.white)),
    );
  }
}

/// Porcentagem de presença do participante (verde ≥ 75%, laranja ≥ 50%).
class _Frequencia extends StatelessWidget {
  const _Frequencia({required this.presencas, required this.marcadas});
  final int presencas;
  final int marcadas;

  @override
  Widget build(BuildContext context) {
    if (marcadas == 0) {
      return Text('—',
          style: fonteIdv(tamanho: 13, cor: StyleProjetos.textoSecundario));
    }
    final pct = (presencas / marcadas * 100).round();
    final cor = pct >= 75
        ? _verde
        : pct >= 50
            ? const Color(0xFFC24A00)
            : _vermelho;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      TagIdv(texto: '$pct%', cor: cor),
      const SizedBox(width: 8),
      Flexible(
        child: Text('$presencas/$marcadas',
            overflow: TextOverflow.ellipsis,
            style: fonteIdv(tamanho: 12, cor: StyleProjetos.textoSecundario)),
      ),
    ]);
  }
}

/// Presente / Falta do dia. Tocar de novo no marcado limpa.
class _MarcarPresenca extends StatelessWidget {
  const _MarcarPresenca({
    required this.status,
    required this.aoMudar,
    this.compacto = false,
  });

  final String status;
  final ValueChanged<String> aoMudar;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _BotaoStatus(
        texto: compacto ? 'P' : 'Presente',
        icone: FontAwesomeIcons.circleCheck,
        cor: _verde,
        marcado: status == 'P',
        aoTocar: () => aoMudar(status == 'P' ? '' : 'P'),
      ),
      const SizedBox(width: 6),
      _BotaoStatus(
        texto: compacto ? 'F' : 'Falta',
        icone: FontAwesomeIcons.circleXmark,
        cor: _vermelho,
        marcado: status == 'F',
        aoTocar: () => aoMudar(status == 'F' ? '' : 'F'),
      ),
    ]);
  }
}

class _BotaoStatus extends StatelessWidget {
  const _BotaoStatus({
    required this.texto,
    required this.icone,
    required this.cor,
    required this.marcado,
    required this.aoTocar,
  });

  final String texto;
  final IconData icone;
  final Color cor;
  final bool marcado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final corTexto = marcado ? cor : StyleProjetos.textoSecundario;
    return Material(
      color: marcado ? cor.withOpacity(0.1) : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: marcado ? cor : const Color(0x260F1030)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            FaIcon(icone, size: 13, color: corTexto),
            const SizedBox(width: 6),
            Text(texto,
                style: fonteIdv(
                    tamanho: 12.5,
                    peso: marcado ? FontWeight.w600 : FontWeight.w500,
                    cor: corTexto)),
          ]),
        ),
      ),
    );
  }
}

// =====================================================================
// Painéis
// =====================================================================

class _PainelNovoDia extends StatefulWidget {
  const _PainelNovoDia({required this.existentes});
  final Set<String> existentes;

  @override
  State<_PainelNovoDia> createState() => _PainelNovoDiaState();
}

class _PainelNovoDiaState extends State<_PainelNovoDia> {
  // Hoje já vem marcado, a não ser que já esteja na lista.
  late DateTime? _data =
      widget.existentes.contains(DateFormat('dd/MM').format(DateTime.now()))
          ? null
          : DateTime.now();

  bool get _repetido =>
      _data != null &&
      widget.existentes.contains(DateFormat('dd/MM').format(_data!));

  @override
  Widget build(BuildContext context) {
    return PainelIdv(
      titulo: 'Adicionar dia',
      ajuda:
          'O dia vira uma nova coluna na planilha de presença do treinamento.',
      largura: 460,
      rotuloAcao: 'Adicionar dia',
      aoConfirmar: _data == null || _repetido
          ? null
          : () => Navigator.pop(context, _data),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RotuloIdv('Data da aula', obrigatorio: true),
          const SizedBox(height: 8),
          CalendarioDiaIdv(
            selecionado: _data,
            aoEscolher: (d) => setState(() => _data = d),
          ),
          if (_repetido) ...[
            const SizedBox(height: 12),
            Text('Esse dia já está na lista.',
                style: fonteIdv(tamanho: 12.5, cor: _vermelho)),
          ],
        ],
      ),
    );
  }
}

class _PainelNovoParticipante extends StatefulWidget {
  const _PainelNovoParticipante();

  @override
  State<_PainelNovoParticipante> createState() =>
      _PainelNovoParticipanteState();
}

class _PainelNovoParticipanteState extends State<_PainelNovoParticipante> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(
        context, (nome: _nome.text.trim(), email: _email.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return PainelIdv(
      titulo: 'Novo participante',
      rotuloAcao: 'Adicionar participante',
      aoConfirmar: _confirmar,
      child: Form(
        key: _form,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CampoIdv(
            rotulo: 'Nome',
            controle: _nome,
            dica: 'Nome completo',
            obrigatorio: true,
            validar: (v) => v.trim().isEmpty ? 'Informe o nome.' : null,
          ),
          CampoIdv(
            rotulo: 'E-mail',
            controle: _email,
            dica: 'participante@empresa.com',
            teclado: TextInputType.emailAddress,
            validar: (v) {
              final t = v.trim();
              if (t.isEmpty) return null;
              return RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(t)
                  ? null
                  : 'E-mail inválido.';
            },
          ),
        ]),
      ),
    );
  }
}

/// Importar a lista: escolher o arquivo, conferir os nomes encontrados e
/// adicionar. Quem já está na lista fica de fora.
class _PainelImportar extends StatefulWidget {
  const _PainelImportar({required this.jaNaLista});
  final Set<String> jaNaLista;

  @override
  State<_PainelImportar> createState() => _PainelImportarState();
}

class _PainelImportarState extends State<_PainelImportar> {
  String? _arquivo;
  String? _erro;
  List<ParticipanteImportado> _lidos = [];

  // Fora quem já está na lista ou aparece repetido no arquivo (inclusive
  // depois de uma edição deixar dois iguais).
  List<ParticipanteImportado> get _novos {
    final vistos = {...widget.jaNaLista};
    return [
      for (final p in _lidos)
        if (vistos.add(chaveParticipante(p.nome, p.email))) p,
    ];
  }

  Future<void> _escolher() async {
    try {
      final arquivo = await escolherArquivo(extensoesParticipantes);
      if (arquivo == null || !mounted) return;
      final lidos = lerParticipantes(arquivo.nome, arquivo.bytes);
      setState(() {
        _arquivo = arquivo.nome;
        _lidos = lidos;
        _erro = lidos.isEmpty ? 'Nenhum nome encontrado no arquivo.' : null;
      });
    } on UnsupportedError {
      setState(() => _erro = 'A importação está disponível só na versão web.');
    } on FormatException catch (e) {
      setState(() => _erro = e.message);
    } catch (_) {
      setState(() => _erro = 'Não foi possível ler o arquivo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final novos = _novos;
    final repetidos = _lidos.length - novos.length;
    return PainelIdv(
      titulo: 'Importar lista',
      ajuda: 'Um participante por linha. No .csv ou na tabela do Word, uma '
          'coluna "Nome" e, se tiver, uma "E-mail". No .txt, "Nome" ou '
          '"Nome - e-mail".',
      rotuloAcao: novos.isEmpty
          ? 'Adicionar participantes'
          : novos.length == 1
              ? 'Adicionar 1 participante'
              : 'Adicionar ${novos.length} participantes',
      aoConfirmar: novos.isEmpty ? null : () => Navigator.pop(context, novos),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AreaArquivo(arquivo: _arquivo, aoTocar: _escolher),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!, style: fonteIdv(tamanho: 12.5, cor: _vermelho)),
          ],
          if (_lidos.isNotEmpty) ...[
            const SizedBox(height: 22),
            SecaoIdv(
              novos.length == 1
                  ? '1 participante novo'
                  : '${novos.length} participantes novos',
              descricao: repetidos == 0
                  ? null
                  : repetidos == 1
                      ? '1 já está na lista e não será adicionado.'
                      : '$repetidos já estão na lista e não serão adicionados.',
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < _lidos.length; i++)
              _LinhaImportada(
                _lidos[i],
                key: ObjectKey(_lidos[i]),
                repetido: !novos.contains(_lidos[i]),
                aoAlterar: (novo) => setState(() => _lidos[i] = novo),
                aoExcluir: () => setState(() => _lidos.removeAt(i)),
              ),
          ],
        ],
      ),
    );
  }
}

class _AreaArquivo extends StatelessWidget {
  const _AreaArquivo({required this.arquivo, required this.aoTocar});
  final String? arquivo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CoresIdv.campo,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: aoTocar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CoresIdv.borda),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: StyleProjetos.azulEscuro),
              alignment: Alignment.center,
              child: FaIcon(
                  arquivo == null
                      ? FontAwesomeIcons.fileImport
                      : FontAwesomeIcons.fileLines,
                  size: 16,
                  color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(arquivo ?? 'Escolher arquivo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: fonteIdv(tamanho: 14, peso: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                      arquivo == null
                          ? '.csv, .txt ou .docx com um participante por linha'
                          : 'Toque para escolher outro arquivo',
                      style: fonteIdv(
                          tamanho: 12.5, cor: CoresIdv.textoSecundario)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

final _emailValido = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

/// Linha da prévia: corrigir (nome e e-mail ali mesmo) ou tirar da lista
/// antes de adicionar.
class _LinhaImportada extends StatefulWidget {
  const _LinhaImportada(
    this.p, {
    super.key,
    required this.repetido,
    required this.aoAlterar,
    required this.aoExcluir,
  });

  final ParticipanteImportado p;
  final bool repetido;
  final ValueChanged<ParticipanteImportado> aoAlterar;
  final VoidCallback aoExcluir;

  @override
  State<_LinhaImportada> createState() => _LinhaImportadaState();
}

class _LinhaImportadaState extends State<_LinhaImportada> {
  bool _editando = false;
  late final _nome = TextEditingController(text: widget.p.nome);
  late final _email = TextEditingController(text: widget.p.email);
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    super.dispose();
  }

  void _salvar() {
    final nome = _nome.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final email = _email.text.trim().toLowerCase();
    if (nome.isEmpty) {
      setState(() => _erro = 'Informe o nome.');
      return;
    }
    if (email.isNotEmpty && !_emailValido.hasMatch(email)) {
      setState(() => _erro = 'E-mail inválido.');
      return;
    }
    setState(() {
      _editando = false;
      _erro = null;
    });
    widget.aoAlterar(ParticipanteImportado(nome, email));
  }

  void _cancelar() => setState(() {
        _nome.text = widget.p.nome;
        _email.text = widget.p.email;
        _editando = false;
        _erro = null;
      });

  Widget _acao(IconData icone, String dica, VoidCallback aoTocar,
          {Color cor = StyleProjetos.azulEscuro}) =>
      IconButton(
        tooltip: dica,
        visualDensity: VisualDensity.compact,
        onPressed: aoTocar,
        icon: FaIcon(icone, size: 15, color: cor),
      );

  Widget _campo(TextEditingController c, String dica, {bool email = false}) =>
      TextField(
        controller: c,
        autofocus: !email,
        keyboardType: email ? TextInputType.emailAddress : TextInputType.name,
        onSubmitted: (_) => _salvar(),
        style: fonteIdv(tamanho: 13.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: dica,
          hintStyle: fonteIdv(tamanho: 13.5, cor: CoresIdv.textoSecundario),
          filled: true,
          fillColor: CoresIdv.campo,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: CoresIdv.borda),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: CoresIdv.borda),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: CoresIdv.laranja),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final Widget conteudo;
    if (_editando) {
      conteudo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(flex: 5, child: _campo(_nome, 'Nome')),
            const SizedBox(width: 8),
            Expanded(
                flex: 5,
                child: _campo(_email, 'E-mail (opcional)', email: true)),
            const SizedBox(width: 4),
            _acao(FontAwesomeIcons.check, 'Salvar', _salvar, cor: _verde),
            _acao(FontAwesomeIcons.xmark, 'Cancelar', _cancelar,
                cor: StyleProjetos.textoSecundario),
          ]),
          if (_erro != null) ...[
            const SizedBox(height: 6),
            Text(_erro!, style: fonteIdv(tamanho: 12, cor: _vermelho)),
          ],
        ],
      );
    } else {
      conteudo = Row(children: [
        Expanded(
          child: Opacity(
            opacity: widget.repetido ? 0.5 : 1,
            child: Row(children: [
              _Avatar(p.nome),
              const SizedBox(width: 12),
              Expanded(
                child: CelulaRelatorio(p.nome,
                    abaixo: p.email.isEmpty ? 'Sem e-mail' : p.email,
                    forte: true),
              ),
              if (widget.repetido)
                const TagIdv(
                    texto: 'Já na lista', cor: StyleProjetos.textoSecundario),
            ]),
          ),
        ),
        const SizedBox(width: 4),
        _acao(FontAwesomeIcons.penToSquare, 'Editar',
            () => setState(() => _editando = true)),
        _acao(FontAwesomeIcons.trashCan, 'Tirar da lista', widget.aoExcluir,
            cor: _vermelho),
      ]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: StyleProjetos.divisoria))),
      child: conteudo,
    );
  }
}
