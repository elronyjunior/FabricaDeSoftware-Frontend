import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fabrica_software_app/config/api_config.dart';
import 'package:fabrica_software_app/services/auth_service.dart';

class ModalCriarTreinamento extends StatefulWidget {
  final int projetoId;
  final VoidCallback onSuccess;
  final Map<String, dynamic>? treinamentoEdicao; // Novo parâmetro opcional

  const ModalCriarTreinamento({
    super.key, 
    required this.projetoId, 
    required this.onSuccess,
    this.treinamentoEdicao, // Pode ser nulo (modo criação)
  });

  @override
  State<ModalCriarTreinamento> createState() => _ModalCriarTreinamentoState();
}

class _ModalCriarTreinamentoState extends State<ModalCriarTreinamento> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nomeCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _instrutorCtrl = TextEditingController();
  final _cargaHorariaCtrl = TextEditingController();
  final _dataInicioCtrl = TextEditingController();
  final _dataTerminoCtrl = TextEditingController();
  
  // Variáveis de Estado
  String _tipoSelecionado = 'Técnico';
  bool _isLoading = false;
  DateTime? _dataInicio;
  DateTime? _dataTermino;

  /// Erro do período (o PeriodoIdv não é um campo de formulário).
  String? _erroPeriodo;

  final List<String> _tipos = ['Técnico', 'Comportamental', 'Gestão', 'Processos', 'Outros'];

  @override
  void initState() {
    super.initState();
    // Se veio dados para edição, preenche os campos
    if (widget.treinamentoEdicao != null) {
      final t = widget.treinamentoEdicao!;
      _nomeCtrl.text = t['nome'] ?? '';
      _descricaoCtrl.text = t['descricao'] ?? '';
      _instrutorCtrl.text = t['instrutor'] ?? '';
      _cargaHorariaCtrl.text = t['duracao_horas']?.toString() ?? '';
      
      // Tipo fora da lista (cadastrado antes, ou pelo banco) virava "Técnico"
      // em silêncio e era sobrescrito ao salvar. Agora entra como opção.
      final tipoAtual = t['tipo_treinamento']?.toString().trim() ?? '';
      if (tipoAtual.isNotEmpty) {
        if (!_tipos.contains(tipoAtual)) _tipos.add(tipoAtual);
        _tipoSelecionado = tipoAtual;
      }

      // Ajusta Datas
      if (t['data_inicio'] != null) {
        _dataInicio = DateTime.parse(t['data_inicio']);
        _dataInicioCtrl.text = DateFormat('dd/MM/yyyy').format(_dataInicio!);
      }
      if (t['data_termino'] != null) {
        _dataTermino = DateTime.parse(t['data_termino']);
        _dataTerminoCtrl.text = DateFormat('dd/MM/yyyy').format(_dataTermino!);
      }
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descricaoCtrl.dispose();
    _instrutorCtrl.dispose();
    _cargaHorariaCtrl.dispose();
    _dataInicioCtrl.dispose();
    _dataTerminoCtrl.dispose();
    super.dispose();
  }

  // Função de Salvar (Cria ou Edita)
  Future<void> _salvar() async {
    final formOk = _formKey.currentState!.validate();
    final periodoOk = _dataInicio != null && _dataTermino != null;
    setState(() => _erroPeriodo =
        periodoOk ? null : 'Escolha o início e o término no calendário.');
    if (!formOk || !periodoOk) return;

    setState(() => _isLoading = true);

    try {
      final token = await AuthService.instance.token;
      final bool isEdicao = widget.treinamentoEdicao != null;
      
      final body = jsonEncode({
        "projeto_id": widget.projetoId,
        "nome": _nomeCtrl.text,
        "descricao": _descricaoCtrl.text,
        "instrutor": _instrutorCtrl.text,
        "tipo_treinamento": _tipoSelecionado,
        "duracao_horas": int.tryParse(_cargaHorariaCtrl.text) ?? 0,
        "data_inicio": _dataInicio?.toIso8601String(),
        "data_termino": _dataTermino?.toIso8601String(),
        // Em edição, mantemos o documento como está, ou null se for novo (backend trata)
        "documento_id": isEdicao ? widget.treinamentoEdicao!['documento_id'] : null 
      });

      http.Response response;

      if (isEdicao) {
        // MODO EDIÇÃO (PUT)
        final id = widget.treinamentoEdicao!['id'];
        response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/treinamentos/$id'),
          headers: ApiConfig.getAuthHeaders(token),
          body: body,
        );
      } else {
        // MODO CRIAÇÃO (POST)
        response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/treinamentos'),
          headers: ApiConfig.getAuthHeaders(token),
          body: body,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          // O painel já fechou: o aviso aparece na tela de trás.
          avisarApp(isEdicao ? "Treinamento atualizado!" : "Treinamento criado!", tipo: TipoAviso.sucesso);
        }
      } else {
        throw Exception("Erro no backend: ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        avisar(context, "Erro: $e", tipo: TipoAviso.erro);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.treinamentoEdicao != null;

    return PainelIdv(
      titulo: isEdicao ? 'Editar treinamento' : 'Novo treinamento',
      rotuloAcao: isEdicao ? 'Salvar alterações' : 'Criar treinamento',
      carregando: _isLoading,
      aoConfirmar: _salvar,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SecaoIdv('Informações gerais'),
            CampoIdv(
              rotulo: 'Nome do treinamento',
              controle: _nomeCtrl,
              obrigatorio: true,
              dica: 'Ex.: Boas práticas com Flutter',
            ),
            LinhaCamposIdv(children: [
              _buildDropdown(),
              CampoIdv(
                rotulo: 'Instrutor',
                controle: _instrutorCtrl,
                obrigatorio: true,
                dica: 'Quem vai conduzir',
              ),
            ]),
            CampoIdv(
              rotulo: 'Descrição',
              controle: _descricaoCtrl,
              obrigatorio: true,
              linhas: 3,
              dica: 'O que será abordado no treinamento',
            ),
            const SizedBox(height: 6),
            const SecaoIdv('Período e carga horária'),
            // Período no padrão do design system: um campo, um calendário
            // (o 1º clique marca o início e o 2º, o término).
            const RotuloIdv('Período', obrigatorio: true),
            PeriodoIdv(
              inicio: _dataInicio,
              fim: _dataTermino,
              aoMudar: (i, f) => setState(() {
                _dataInicio = i;
                _dataTermino = f;
                if (i != null && f != null) _erroPeriodo = null;
              }),
            ),
            if (_erroPeriodo != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 16),
                child: Text(_erroPeriodo!,
                    style: fonteIdv(tamanho: 12, cor: CoresIdv.vermelho)),
              ),
            const SizedBox(height: 18),
            CampoIdv(
              rotulo: 'Carga horária (h)',
              controle: _cargaHorariaCtrl,
              obrigatorio: true,
              dica: 'Ex.: 8',
              teclado: TextInputType.number,
              formatadores: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RotuloIdv('Tipo', obrigatorio: true),
          SelecaoIdv<String>(
            hint: 'Escolha o tipo',
            valor: _tipoSelecionado,
            itens: _tipos,
            rotulo: (t) => t,
            aoMudar: (v) {
              if (v != null) setState(() => _tipoSelecionado = v);
            },
          ),
        ],
      ),
    );
  }
}
