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
      
      // Ajusta Tipo (Garante que está na lista, senão default)
      if (_tipos.contains(t['tipo_treinamento'])) {
        _tipoSelecionado = t['tipo_treinamento'];
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

  // Função de Salvar (Cria ou Edita)
  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

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

  Future<void> _selecionarData(bool isInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isInicio ? (_dataInicio ?? DateTime.now()) : (_dataTermino ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(data: ThemeData.light().copyWith(primaryColor: const Color(0xFF2563EB)), child: child!),
    );

    if (picked != null) {
      setState(() {
        if (isInicio) {
          _dataInicio = picked;
          _dataInicioCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
        } else {
          _dataTermino = picked;
          _dataTerminoCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
        }
      });
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
            LinhaCamposIdv(children: [
              _buildDatePicker('Data de início', _dataInicioCtrl,
                  () => _selecionarData(true)),
              _buildDatePicker('Data de término', _dataTerminoCtrl,
                  () => _selecionarData(false)),
            ]),
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

  /// Data no visual dos campos; o calendário abre ao tocar.
  Widget _buildDatePicker(
      String label, TextEditingController ctrl, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RotuloIdv(label, obrigatorio: true),
          TextFormField(
            controller: ctrl,
            readOnly: true,
            onTap: onTap,
            style: fonteIdv(),
            mouseCursor: SystemMouseCursors.click,
            validator: (v) => v == null || v.isEmpty
                ? 'Escolha a ${label.toLowerCase()}'
                : null,
            decoration: decoracaoCampoIdv(
              dica: 'dd/mm/aaaa',
              sufixo: const Icon(Icons.calendar_today_rounded,
                  size: 18, color: CoresIdv.textoSecundario),
            ),
          ),
        ],
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
