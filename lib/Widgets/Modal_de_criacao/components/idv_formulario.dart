import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/Steps/Configuracao_Inicial_Projeto_step/components.dart';
import 'package:fabrica_software_app/screens/Gerenciar_Projetos/Styles/style_projetos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// =====================================================================
// Componentes do formulário de projeto no tema da IDV (azul-escuro,
// laranja, Inter, bordas finas e nada de sombra).
// =====================================================================

class CoresIdv {
  CoresIdv._();

  static const azul = StyleProjetos.azulEscuro;
  static const laranja = StyleProjetos.laranja;
  static const texto = StyleProjetos.texto;
  static const textoSecundario = StyleProjetos.textoSecundario;
  static const campo = ComponentsConfiguracaoInicalProjeto.fundoCampo;
  static const borda = ComponentsConfiguracaoInicalProjeto.bordaCampo;

  /// Fundo de item selecionado / faixa do período no calendário.
  static const azulSuave = Color(0x140F1030);
  static const laranjaSuave = Color(0x1AFF5F00);
  static const verde = Color(0xFF2E8B57);
  static const vermelho = Color(0xFFD64545);
}

TextStyle fonteIdv({
  double tamanho = 14,
  FontWeight peso = FontWeight.w400,
  Color cor = CoresIdv.texto,
  double? altura,
}) =>
    GoogleFonts.inter(
        fontSize: tamanho, fontWeight: peso, color: cor, height: altura);

/// Ícone "?" que mostra uma explicação ao passar o mouse.
class AjudaIdv extends StatelessWidget {
  const AjudaIdv({super.key, required this.texto, this.tamanho = 20});

  final String texto;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: texto,
      waitDuration: const Duration(milliseconds: 150),
      preferBelow: true,
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CoresIdv.azul,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: fonteIdv(tamanho: 13, cor: Colors.white, altura: 1.4),
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        child: Icon(Icons.help_outline_rounded,
            size: tamanho, color: CoresIdv.textoSecundario),
      ),
    );
  }
}

/// Caixa de seleção (dropdown) no visual dos campos.
class SelecaoIdv<T> extends StatelessWidget {
  const SelecaoIdv({
    super.key,
    required this.hint,
    required this.valor,
    required this.itens,
    required this.rotulo,
    required this.aoMudar,
  });

  final String hint;
  final T? valor;
  final List<T> itens;
  final String Function(T item) rotulo;
  final ValueChanged<T?> aoMudar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: ComponentsConfiguracaoInicalProjeto.inputBoxDecoration,
      padding: const EdgeInsets.only(left: 16, right: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valor,
          isExpanded: true,
          hint: Text(hint,
              style: fonteIdv(cor: CoresIdv.textoSecundario),
              overflow: TextOverflow.ellipsis),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: CoresIdv.textoSecundario),
          style: fonteIdv(),
          dropdownColor: Colors.white,
          focusColor: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          elevation: 2,
          menuMaxHeight: 320,
          items: itens
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(rotulo(item),
                        overflow: TextOverflow.ellipsis, style: fonteIdv()),
                  ))
              .toList(),
          onChanged: aoMudar,
        ),
      ),
    );
  }
}

/// Campo de busca pequeno usado nas listas de seleção.
class BuscaIdv extends StatelessWidget {
  const BuscaIdv({super.key, required this.hint, required this.aoMudar});

  final String hint;
  final ValueChanged<String> aoMudar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: ComponentsConfiguracaoInicalProjeto.inputBoxDecoration,
      child: TextField(
        onChanged: aoMudar,
        style: fonteIdv(),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: fonteIdv(cor: CoresIdv.textoSecundario),
          border: InputBorder.none,
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: CoresIdv.textoSecundario),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// Botão das ações de IA: azul-escuro com o ícone em laranja.
class BotaoIa extends StatelessWidget {
  const BotaoIa({
    super.key,
    required this.rotulo,
    required this.aoTocar,
    this.carregando = false,
    this.rotuloCarregando,
    this.larguraTotal = true,
  });

  final String rotulo;
  final String? rotuloCarregando;
  final VoidCallback? aoTocar;
  final bool carregando;
  final bool larguraTotal;

  @override
  Widget build(BuildContext context) {
    final botao = ElevatedButton(
      onPressed: carregando ? null : aoTocar,
      style: ElevatedButton.styleFrom(
        backgroundColor: CoresIdv.azul,
        foregroundColor: Colors.white,
        disabledBackgroundColor: CoresIdv.azul.withOpacity(0.55),
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: fonteIdv(tamanho: 14, peso: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (carregando)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
          else
            const Icon(FontAwesomeIcons.wandMagicSparkles,
                size: 14, color: StyleProjetos.laranjaClaro),
          const SizedBox(width: 10),
          Text(carregando ? (rotuloCarregando ?? rotulo) : rotulo),
        ],
      ),
    );
    return larguraTotal
        ? SizedBox(width: double.infinity, child: botao)
        : botao;
  }
}

/// Etiqueta pequena (tipo, prioridade, origem...).
class TagIdv extends StatelessWidget {
  const TagIdv({super.key, required this.texto, required this.cor, this.icone});

  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 10, color: cor),
            const SizedBox(width: 4),
          ],
          Text(texto,
              style: fonteIdv(tamanho: 11, peso: FontWeight.w600, cor: cor)),
        ],
      ),
    );
  }
}

/// Marcador quadrado de selecionado.
class _Marcador extends StatelessWidget {
  const _Marcador({required this.marcado});
  final bool marcado;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: marcado ? CoresIdv.azul : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: marcado ? CoresIdv.azul : const Color(0x590F1030),
            width: 1.5),
      ),
      child: marcado
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _AvatarIdv extends StatelessWidget {
  const _AvatarIdv({required this.nome, this.raio = 15});
  final String nome;
  final double raio;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: raio,
      backgroundColor: CoresIdv.azul,
      child: Text(
        nome.isEmpty ? '?' : nome[0].toUpperCase(),
        style: fonteIdv(
            tamanho: raio * 0.8, peso: FontWeight.w600, cor: Colors.white),
      ),
    );
  }
}

/// Busca com resultados logo abaixo, feita para listas grandes (milhares de
/// pessoas, centenas de tecnologias): só aparecem os resultados da busca, e
/// o que foi escolhido fica em etiquetas abaixo do campo.
///
/// Com [grupo], os resultados vêm separados por grupo (ex.: categoria).
/// Com [listarSemBusca], o campo focado e vazio já lista tudo (agrupado);
/// sem ele, mostra só algumas sugestões e pede para digitar.
class BuscaSelecaoIdv extends StatefulWidget {
  const BuscaSelecaoIdv({
    super.key,
    required this.itens,
    required this.rotulo,
    required this.marcado,
    required this.aoAlternar,
    this.detalhe,
    this.grupo,
    this.comAvatar = false,
    this.listarSemBusca = false,
    this.hintBusca = 'Pesquisar',
    this.textoVazio = 'Nada cadastrado.',
    this.textoNenhumSelecionado = 'Nada selecionado ainda.',
    this.unico = false,
  });

  final List<dynamic> itens;
  final String Function(dynamic item) rotulo;
  final String? Function(dynamic item)? detalhe;
  final String? Function(dynamic item)? grupo;
  final bool Function(dynamic item) marcado;
  final ValueChanged<dynamic> aoAlternar;
  final bool comAvatar;
  final bool listarSemBusca;
  final String hintBusca;
  final String textoVazio;
  final String textoNenhumSelecionado;

  /// Escolha de um item só (ex.: cliente): a lista fecha ao escolher.
  final bool unico;

  @override
  State<BuscaSelecaoIdv> createState() => _BuscaSelecaoIdvState();
}

class _BuscaSelecaoIdvState extends State<BuscaSelecaoIdv> {
  static const _limiteSugestoes = 8;
  static const _limiteResultados = 40;

  final _busca = TextEditingController();
  final _foco = FocusNode();
  final _grupoToque = Object();
  final _chaveLista = GlobalKey();
  bool _aberto = false;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (_foco.hasFocus && !_aberto) {
        setState(() => _aberto = true);
        _mostrarLista();
      }
    });
  }

  /// Rola o formulário até a lista aberta aparecer inteira (o usuário não
  /// precisa rolar para ver os resultados). Espera a lista terminar de abrir.
  void _mostrarLista() {
    Future.delayed(const Duration(milliseconds: 200), () {
      final alvo = _chaveLista.currentContext;
      if (!mounted || alvo == null) return;
      Scrollable.ensureVisible(
        alvo,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  void dispose() {
    _busca.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _fechar() {
    _foco.unfocus();
    if (_aberto) setState(() => _aberto = false);
  }

  String _texto(dynamic item) =>
      '${widget.rotulo(item)} ${widget.detalhe?.call(item) ?? ''} '
              '${widget.grupo?.call(item) ?? ''}'
          .toLowerCase();

  @override
  Widget build(BuildContext context) {
    final selecionados = widget.itens.where(widget.marcado).toList();

    return TapRegion(
      groupId: _grupoToque,
      onTapOutside: (_) => _fechar(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _campoBusca(),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _aberto
                ? Padding(
                    key: _chaveLista,
                    padding: const EdgeInsets.only(top: 8),
                    child: _resultados(),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 12),
          if (selecionados.isEmpty)
            Text(widget.textoNenhumSelecionado,
                style: fonteIdv(tamanho: 13, cor: CoresIdv.textoSecundario))
          else
            // Cada etiqueta cabe na largura do campo; nome longo vira "...".
            LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in selecionados)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: c.maxWidth),
                      child: _etiqueta(item),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _campoBusca() {
    return Container(
      height: 46,
      decoration: ComponentsConfiguracaoInicalProjeto.inputBoxDecoration
          .copyWith(
              border:
                  Border.all(color: _aberto ? CoresIdv.azul : CoresIdv.borda)),
      child: TextField(
        controller: _busca,
        focusNode: _foco,
        onChanged: (_) {
          if (!_aberto) _mostrarLista();
          setState(() => _aberto = true);
        },
        onSubmitted: (_) {
          // Enter escolhe o primeiro resultado ainda não marcado.
          final termo = _busca.text.trim().toLowerCase();
          if (termo.isEmpty) return;
          final primeiro = widget.itens.firstWhere(
              (i) => !widget.marcado(i) && _texto(i).contains(termo),
              orElse: () => null);
          if (primeiro != null) widget.aoAlternar(primeiro);
          if (widget.unico && primeiro != null) {
            _busca.clear();
            _fechar();
          } else {
            _foco.requestFocus();
          }
        },
        style: fonteIdv(),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: widget.hintBusca,
          hintStyle: fonteIdv(cor: CoresIdv.textoSecundario),
          border: InputBorder.none,
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: CoresIdv.textoSecundario),
          suffixIcon: _aberto
              ? IconButton(
                  tooltip: 'Fechar lista',
                  onPressed: () {
                    _busca.clear();
                    _fechar();
                  },
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: CoresIdv.textoSecundario),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _resultados() {
    final termo = _busca.text.trim().toLowerCase();

    if (widget.itens.isEmpty) return _aviso(widget.textoVazio);

    List<dynamic> lista;
    String? rodape;
    if (termo.isEmpty) {
      if (widget.listarSemBusca) {
        lista = widget.itens;
      } else {
        lista = widget.itens.take(_limiteSugestoes).toList();
        if (widget.itens.length > _limiteSugestoes) {
          rodape =
              '${widget.itens.length} cadastrados. Digite um nome para encontrar mais rápido.';
        }
      }
    } else {
      final achados = widget.itens.where((i) => _texto(i).contains(termo));
      final total = achados.length;
      if (total == 0) return _aviso('Nenhum resultado para "${_busca.text}".');
      lista = achados.take(_limiteResultados).toList();
      if (total > _limiteResultados) {
        rodape =
            'Mostrando $_limiteResultados de $total. Continue digitando para refinar.';
      }
    }

    final linhas = <Widget>[];
    if (widget.grupo != null) {
      final grupos = <String, List<dynamic>>{};
      for (final item in lista) {
        final nome = (widget.grupo!(item) ?? '').trim();
        grupos.putIfAbsent(nome.isEmpty ? 'Outros' : nome, () => []).add(item);
      }
      final nomes = grupos.keys.toList()
        ..sort((a, b) => a == 'Outros'
            ? 1
            : b == 'Outros'
                ? -1
                : a.toLowerCase().compareTo(b.toLowerCase()));
      for (final nome in nomes) {
        linhas.add(_cabecalhoGrupo(nome, grupos[nome]!.length));
        linhas.addAll(grupos[nome]!.map(_linha));
      }
    } else {
      linhas.addAll(lista.map(_linha));
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CoresIdv.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: linhas,
            ),
          ),
          if (rodape != null)
            Container(
              color: CoresIdv.campo,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(rodape,
                  style: fonteIdv(tamanho: 12, cor: CoresIdv.textoSecundario)),
            ),
        ],
      ),
    );
  }

  Widget _aviso(String texto) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CoresIdv.borda),
        ),
        child: Text(texto,
            textAlign: TextAlign.center,
            style: fonteIdv(tamanho: 13, cor: CoresIdv.textoSecundario)),
      );

  Widget _cabecalhoGrupo(String nome, int quantidade) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Text('${nome.toUpperCase()}  ·  $quantidade',
            style: fonteIdv(
                tamanho: 11,
                peso: FontWeight.w700,
                cor: CoresIdv.textoSecundario)),
      );

  Widget _linha(dynamic item) {
    final marcado = widget.marcado(item);
    final nome = widget.rotulo(item);
    final detalhe = widget.detalhe?.call(item);

    return Material(
      color: marcado ? CoresIdv.azulSuave : Colors.white,
      child: InkWell(
        onTap: () {
          widget.aoAlternar(item);
          if (widget.unico) {
            _busca.clear();
            _fechar();
          } else {
            _foco.requestFocus();
          }
        },
        hoverColor: const Color(0x0A0F1030),
        splashColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              _Marcador(marcado: marcado),
              const SizedBox(width: 12),
              if (widget.comAvatar) ...[
                _AvatarIdv(nome: nome, raio: 14),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(nome,
                    overflow: TextOverflow.ellipsis,
                    style: fonteIdv(peso: FontWeight.w500)),
              ),
              if (detalhe != null && detalhe.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(detalhe,
                      style:
                          fonteIdv(tamanho: 13, cor: CoresIdv.textoSecundario)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _etiqueta(dynamic item) {
    final nome = widget.rotulo(item);
    final detalhe = widget.detalhe?.call(item);

    return Container(
      padding: EdgeInsets.fromLTRB(widget.comAvatar ? 5 : 12, 5, 6, 5),
      decoration: BoxDecoration(
        color: CoresIdv.azulSuave,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.comAvatar) ...[
            _AvatarIdv(nome: nome, raio: 12),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: fonteIdv(tamanho: 13, peso: FontWeight.w600)),
          ),
          if (detalhe != null && detalhe.isNotEmpty) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(detalhe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: fonteIdv(tamanho: 12, cor: CoresIdv.textoSecundario)),
            ),
          ],
          const SizedBox(width: 2),
          InkWell(
            onTap: () => widget.aoAlternar(item),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.close_rounded,
                  size: 15, color: CoresIdv.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }
}

/// Escolha entre poucas opções lado a lado (tipo, prioridade...): mostra
/// todas de uma vez, sem cortar o texto.
class OpcoesIdv<T> extends StatelessWidget {
  const OpcoesIdv({
    super.key,
    required this.opcoes,
    required this.valor,
    required this.aoMudar,
    this.rotulo,
  });

  final List<T> opcoes;
  final T valor;
  final ValueChanged<T> aoMudar;
  final String Function(T)? rotulo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: ComponentsConfiguracaoInicalProjeto.inputBoxDecoration,
      child: Row(
        children: [
          for (final opcao in opcoes)
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => aoMudar(opcao),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color:
                          opcao == valor ? CoresIdv.azul : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        rotulo?.call(opcao) ?? '$opcao',
                        maxLines: 1,
                        style: fonteIdv(
                          tamanho: 13,
                          peso: FontWeight.w600,
                          cor: opcao == valor
                              ? Colors.white
                              : CoresIdv.textoSecundario,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================================
// Avisos no canto superior direito
// =====================================================================

enum TipoAviso { erro, sucesso, info }

/// Mostra um aviso no canto superior direito do painel (com X para fechar).
/// Fora do painel, cai no SnackBar normal.
void avisar(BuildContext context, String texto,
    {TipoAviso tipo = TipoAviso.erro}) {
  final avisos = context.findAncestorStateOfType<AvisosIdvState>() ??
      AvisosIdv.global.currentState;
  if (avisos != null) {
    avisos.mostrar(texto, tipo: tipo);
    return;
  }
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    content: Text(texto),
    backgroundColor: switch (tipo) {
      TipoAviso.erro => CoresIdv.vermelho,
      TipoAviso.sucesso => CoresIdv.verde,
      TipoAviso.info => CoresIdv.azul,
    },
  ));
}

/// Aviso sem precisar de BuildContext (ex.: depois de fechar um modal).
void avisarApp(String texto, {TipoAviso tipo = TipoAviso.erro}) =>
    AvisosIdv.global.currentState?.mostrar(texto, tipo: tipo);

/// Traduz os erros das chamadas de IA para uma mensagem curta.
String mensagemErroIa(Object erro) {
  final texto = erro.toString();
  if (texto.contains('usage limits')) {
    final data =
        RegExp(r'regain access on (\d{4})-(\d{2})-(\d{2})').firstMatch(texto);
    final quando = data == null
        ? ''
        : ' Ela volta a funcionar em ${data.group(3)}/${data.group(2)}/${data.group(1)}.';
    return 'A IA atingiu o limite de uso da conta.$quando '
        'Enquanto isso, preencha manualmente.';
  }
  if (texto.contains('credit balance')) {
    return 'A conta da IA está sem créditos. Enquanto isso, preencha manualmente.';
  }
  if (texto.contains('Failed to fetch') ||
      texto.contains('XMLHttpRequest') ||
      texto.contains('SocketException') ||
      texto.contains('Connection refused')) {
    return 'Não foi possível falar com o servidor. Confira se o back-end está rodando.';
  }
  return 'A IA não respondeu agora. Tente novamente em instantes.';
}

class AvisosIdv extends StatefulWidget {
  const AvisosIdv({super.key, required this.child});
  final Widget child;

  /// Avisos do app inteiro (colocado no LayoutPrincipal, por cima de todas
  /// as telas e diálogos). Use [avisar] ou [avisarApp].
  static final global = GlobalKey<AvisosIdvState>();

  @override
  State<AvisosIdv> createState() => AvisosIdvState();
}

class _AvisoItem {
  _AvisoItem(this.id, this.texto, this.tipo);
  final int id;
  final String texto;
  final TipoAviso tipo;
}

class AvisosIdvState extends State<AvisosIdv> {
  final _avisos = <_AvisoItem>[];
  int _proximoId = 0;

  void mostrar(String texto, {TipoAviso tipo = TipoAviso.erro}) {
    // Mesmo aviso repetido: não empilha.
    if (_avisos.any((a) => a.texto == texto)) return;
    final aviso = _AvisoItem(_proximoId++, texto, tipo);
    setState(() {
      _avisos.add(aviso);
      if (_avisos.length > 3) _avisos.removeAt(0);
    });
    Future.delayed(Duration(seconds: tipo == TipoAviso.erro ? 8 : 5),
        () => _fechar(aviso.id));
  }

  void _fechar(int id) {
    if (!mounted) return;
    setState(() => _avisos.removeWhere((a) => a.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final aviso in _avisos)
                _CartaoAviso(
                  key: ValueKey(aviso.id),
                  aviso: aviso,
                  aoFechar: () => _fechar(aviso.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartaoAviso extends StatelessWidget {
  const _CartaoAviso({super.key, required this.aviso, required this.aoFechar});
  final _AvisoItem aviso;
  final VoidCallback aoFechar;

  @override
  Widget build(BuildContext context) {
    final (cor, icone) = switch (aviso.tipo) {
      TipoAviso.erro => (CoresIdv.vermelho, Icons.error_outline_rounded),
      TipoAviso.sucesso => (CoresIdv.verde, Icons.check_circle_outline_rounded),
      TipoAviso.info => (CoresIdv.azul, Icons.info_outline_rounded),
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (_, t, filho) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(24 * (1 - t), 0), child: filho),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 360,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CoresIdv.borda),
            // Única sombra do painel: o aviso flutua sobre o conteúdo.
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1F0F1030),
                  blurRadius: 18,
                  offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icone, size: 20, color: cor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(aviso.texto,
                      style: fonteIdv(tamanho: 13, altura: 1.45)),
                ),
              ),
              InkWell(
                onTap: aoFechar,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: CoresIdv.textoSecundario),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Calendário de período (início e fim no mesmo calendário)
// =====================================================================

const _meses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', //
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];
const _diasSemana = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

String formatarDataIdv(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Campo de período: ao abrir mostra um calendário; o primeiro clique marca
/// o início e o segundo marca o fim.
class PeriodoIdv extends StatefulWidget {
  const PeriodoIdv({
    super.key,
    required this.inicio,
    required this.fim,
    required this.aoMudar,
  });

  final DateTime? inicio;
  final DateTime? fim;
  final void Function(DateTime? inicio, DateTime? fim) aoMudar;

  @override
  State<PeriodoIdv> createState() => _PeriodoIdvState();
}

class _PeriodoIdvState extends State<PeriodoIdv> {
  bool _aberto = false;
  late DateTime _mes;
  DateTime? _sobre; // dia sob o mouse, para pré-visualizar o período

  @override
  void initState() {
    super.initState();
    final base = widget.inicio ?? DateTime.now();
    _mes = DateTime(base.year, base.month);
  }

  void _escolher(DateTime dia) {
    final inicio = widget.inicio;
    final fim = widget.fim;
    if (inicio == null || fim != null || dia.isBefore(inicio)) {
      widget.aoMudar(dia, null);
    } else {
      widget.aoMudar(inicio, dia);
      setState(() => _aberto = false);
    }
  }

  String get _textoCampo {
    final i = widget.inicio, f = widget.fim;
    if (i == null) return 'Selecione o início e o fim';
    if (f == null) return '${formatarDataIdv(i)}  →  selecione o fim';
    final dias = f.difference(i).inDays + 1;
    return '${formatarDataIdv(i)}  →  ${formatarDataIdv(f)}   ·   $dias dias';
  }

  @override
  Widget build(BuildContext context) {
    final vazio = widget.inicio == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() => _aberto = !_aberto),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: ComponentsConfiguracaoInicalProjeto.inputBoxDecoration
                  .copyWith(
                      border: Border.all(
                          color: _aberto ? CoresIdv.azul : CoresIdv.borda)),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 20,
                      color: vazio ? CoresIdv.textoSecundario : CoresIdv.azul),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_textoCampo,
                        overflow: TextOverflow.ellipsis,
                        style: fonteIdv(
                            cor: vazio
                                ? CoresIdv.textoSecundario
                                : CoresIdv.texto)),
                  ),
                  Icon(
                      _aberto
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: CoresIdv.textoSecundario),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _aberto
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _calendario(),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _calendario() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CoresIdv.borda),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final doisMeses = c.maxWidth >= 560;
        final segundo = DateTime(_mes.year, _mes.month + 1);
        return Column(
          children: [
            Row(
              children: [
                _seta(
                    Icons.chevron_left_rounded,
                    () => setState(
                        () => _mes = DateTime(_mes.year, _mes.month - 1))),
                Expanded(child: _tituloMes(_mes)),
                if (doisMeses) Expanded(child: _tituloMes(segundo)),
                _seta(
                    Icons.chevron_right_rounded,
                    () => setState(
                        () => _mes = DateTime(_mes.year, _mes.month + 1))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _grade(_mes)),
                if (doisMeses) ...[
                  const SizedBox(width: 24),
                  Expanded(child: _grade(segundo)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.inicio == null
                        ? 'Clique no dia de início.'
                        : widget.fim == null
                            ? 'Agora clique no dia de término.'
                            : 'Clique em outro dia para recomeçar.',
                    style: fonteIdv(tamanho: 12, cor: CoresIdv.textoSecundario),
                  ),
                ),
                if (widget.inicio != null)
                  TextButton(
                    onPressed: () => widget.aoMudar(null, null),
                    style: TextButton.styleFrom(
                        foregroundColor: CoresIdv.textoSecundario),
                    child: Text('Limpar',
                        style: fonteIdv(
                            tamanho: 13,
                            peso: FontWeight.w600,
                            cor: CoresIdv.textoSecundario)),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _seta(IconData icone, VoidCallback aoTocar) => IconButton(
        onPressed: aoTocar,
        icon: Icon(icone, color: CoresIdv.texto),
        splashRadius: 18,
        visualDensity: VisualDensity.compact,
      );

  Widget _tituloMes(DateTime mes) => Text(
        '${_meses[mes.month - 1]} ${mes.year}',
        textAlign: TextAlign.center,
        style: fonteIdv(tamanho: 14, peso: FontWeight.w600),
      );

  Widget _grade(DateTime mes) {
    final primeiro = DateTime(mes.year, mes.month, 1);
    final diasNoMes = DateTime(mes.year, mes.month + 1, 0).day;
    final deslocamento = primeiro.weekday % 7; // domingo = 0
    final celulas = <Widget>[
      for (final d in _diasSemana)
        Center(
            child: Text(d,
                style: fonteIdv(
                    tamanho: 12,
                    peso: FontWeight.w600,
                    cor: CoresIdv.textoSecundario))),
      for (var i = 0; i < deslocamento; i++) const SizedBox.shrink(),
      for (var d = 1; d <= diasNoMes; d++)
        _celula(DateTime(mes.year, mes.month, d)),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      children: celulas,
    );
  }

  Widget _celula(DateTime dia) {
    final inicio = widget.inicio;
    // Sem fim definido, o período acompanha o mouse.
    final fim = widget.fim ??
        (inicio != null && _sobre != null && !_sobre!.isBefore(inicio)
            ? _sobre
            : null);

    final ehInicio = inicio != null && dia == _dia(inicio);
    final ehFim = fim != null && dia == _dia(fim);
    final noMeio = inicio != null &&
        fim != null &&
        dia.isAfter(_dia(inicio)) &&
        dia.isBefore(_dia(fim));
    final ponta = ehInicio || ehFim;
    final hoje = dia == _dia(DateTime.now());
    final periodo = inicio != null && fim != null && _dia(inicio) != _dia(fim);
    // Faixa contínua entre o início e o fim: cada dia pinta a metade
    // esquerda e/ou direita da célula.
    final faixaEsquerda = periodo && (noMeio || ehFim);
    final faixaDireita = periodo && (noMeio || ehInicio);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (widget.inicio != null && widget.fim == null) {
          setState(() => _sobre = dia);
        }
      },
      child: GestureDetector(
        onTap: () => _escolher(dia),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              top: 4,
              bottom: 4,
              child: Row(
                children: [
                  Expanded(
                      child: ColoredBox(
                          color: faixaEsquerda
                              ? CoresIdv.azulSuave
                              : Colors.transparent)),
                  Expanded(
                      child: ColoredBox(
                          color: faixaDireita
                              ? CoresIdv.azulSuave
                              : Colors.transparent)),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ponta ? CoresIdv.azul : Colors.transparent,
                shape: BoxShape.circle,
                border: hoje && !ponta
                    ? Border.all(color: CoresIdv.laranja, width: 1.5)
                    : null,
              ),
              child: Text(
                '${dia.day}',
                style: fonteIdv(
                  tamanho: 13,
                  peso: ponta ? FontWeight.w700 : FontWeight.w500,
                  cor: ponta ? Colors.white : CoresIdv.texto,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Normalização dos campos
// =====================================================================

/// Limites de tamanho dos campos de texto do formulário.
class LimitesIdv {
  LimitesIdv._();

  static const nome = 120;
  static const metodologia = 60;
  static const descricao = 1000;
  static const escopo = 3000;
  static const tituloRequisito = 150;
  static const descricaoRequisito = 1000;
}

/// Formatadores comuns: limite de tamanho e sem espaço no começo.
List<TextInputFormatter> textoIdv(int limite) => [
      LengthLimitingTextInputFormatter(limite),
      FilteringTextInputFormatter.deny(RegExp(r'^\s+')),
    ];

/// Campo de valor em reais: só aceita números e formata enquanto digita
/// (1234567 -> 12.345,67).
class FormatoMoedaBr extends TextInputFormatter {
  static const _maxDigitos = 13; // até 99.999.999.999,99

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digitos = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.isEmpty) return const TextEditingValue();
    digitos = digitos.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digitos.length > _maxDigitos) return oldValue;
    final texto = formatarMoedaBr(int.parse(digitos) / 100);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// 12345.6 -> "12.345,60"
String formatarMoedaBr(double valor) {
  final centavos = (valor * 100).round();
  final inteiro = (centavos ~/ 100).toString();
  final decimais = (centavos % 100).toString().padLeft(2, '0');
  final grupos = <String>[];
  for (var i = inteiro.length; i > 0; i -= 3) {
    grupos.insert(0, inteiro.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '${grupos.join('.')},$decimais';
}

/// "12.345,60" -> 12345.6 (null se vazio ou inválido)
double? lerMoedaBr(String texto) {
  final limpo = texto.replaceAll('.', '').replaceAll(',', '.').trim();
  if (limpo.isEmpty) return null;
  return double.tryParse(limpo);
}

// =====================================================================
// Assistente de IA em painel filho (abre ao lado do modal)
// =====================================================================

/// Controla o painel filho do assistente de IA. A aba que está aberta
/// registra o conteúdo do chat; o modal mostra a aba "Assistente IA" na
/// borda e, quando aberto, o painel ao lado.
class AssistenteIdv extends ChangeNotifier {
  String? _donoAtivo;
  String? _dono;
  WidgetBuilder? _conteudo;
  bool _aberto = false;

  bool get disponivel => _conteudo != null;
  bool get aberto => _aberto && _conteudo != null;

  Widget construir(BuildContext context) => _conteudo!(context);

  /// Aba visível no momento: só ela pode registrar o assistente.
  void ativar(String dono) {
    if (_donoAtivo == dono) return;
    _donoAtivo = dono;
    _dono = null;
    _conteudo = null;
    _aberto = false;
    _avisar();
  }

  /// Chamado pela aba a cada build: [conteudo] nulo = sem assistente agora.
  void registrar(String dono, WidgetBuilder? conteudo) {
    if (dono != _donoAtivo) return;
    final mudou = (conteudo == null) != (_conteudo == null) || _dono != dono;
    _dono = dono;
    _conteudo = conteudo;
    if (conteudo == null) _aberto = false;
    if (mudou) _avisar();
  }

  void abrir() {
    _aberto = true;
    _avisar();
  }

  void fechar() {
    _aberto = false;
    _avisar();
  }

  /// O conteúdo do chat mudou (mensagens, carregando...).
  void atualizar() => _avisar();

  void _avisar() {
    // Avisar no meio de um build quebraria o modal; espera o frame acabar.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}

/// Dá às abas acesso ao [AssistenteIdv] do modal.
class EscopoAssistenteIdv extends InheritedWidget {
  const EscopoAssistenteIdv(
      {super.key, required this.assistente, required super.child});

  final AssistenteIdv assistente;

  static AssistenteIdv? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EscopoAssistenteIdv>()?.assistente;

  @override
  bool updateShouldNotify(EscopoAssistenteIdv oldWidget) =>
      assistente != oldWidget.assistente;
}

/// Botão ao lado do modal, na altura da barra de abas, que abre o
/// assistente.
class AbaAssistenteIdv extends StatelessWidget {
  const AbaAssistenteIdv({super.key, required this.aoAbrir});
  final VoidCallback aoAbrir;

  /// Mesma altura da barra de abas do modal.
  static const altura = 48.0;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(14);
    return Tooltip(
      message: 'Abrir o assistente de IA',
      child: Material(
        color: CoresIdv.azul,
        borderRadius: forma,
        child: InkWell(
          onTap: aoAbrir,
          borderRadius: forma,
          child: SizedBox(
            height: altura,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FontAwesomeIcons.wandMagicSparkles,
                      size: 15, color: StyleProjetos.laranjaClaro),
                  const SizedBox(width: 10),
                  Text('Assistente IA',
                      style: fonteIdv(
                          tamanho: 15,
                          peso: FontWeight.w600,
                          cor: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
