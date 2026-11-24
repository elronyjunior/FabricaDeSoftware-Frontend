import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/idv_formulario.dart';
import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:fabrica_software_app/models/teste.dart';
import 'package:flutter/material.dart';


class TesteModal extends StatefulWidget {
  final int projetoId;
  final Teste? testeExistente;
  final Function(Teste) onSave;

  const TesteModal({
    Key? key,
    required this.projetoId,
    this.testeExistente,
    required this.onSave,
  }) : super(key: key);

  @override
  State<TesteModal> createState() => _TesteModalState();
}

class _TesteModalState extends State<TesteModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  String _situacao = 'pendente';
  bool _isSaving = false;

  final Map<String, String> _situacaoLabels = {
    'pendente': 'Pendente',
    'em_progresso': 'Em Execução',
    'concluido': 'Concluído',
    'falha': 'Falha / Erro',
  };

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.testeExistente?.nome ?? '');
    _descricaoController = TextEditingController(text: widget.testeExistente?.descricao ?? '');
    if (widget.testeExistente != null) {
      _situacao = _normalizarSituacao(widget.testeExistente!.situacao);
    }
  }

  // Uma situação do banco fora das chaves (ex.: "Concluído", "em progresso")
  // deixava o dropdown sem item selecionado. Primeiro tenta casar com uma
  // chave conhecida; se não der, mantém o valor e o inclui como opção, para
  // não trocar a situação do teste sem o usuário pedir.
  String _normalizarSituacao(String bruto) {
    final valor = bruto.trim();
    if (valor.isEmpty) return 'pendente';
    if (_situacaoLabels.containsKey(valor)) return valor;
    final chave = valor
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll('í', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('ã', 'a');
    if (_situacaoLabels.containsKey(chave)) return chave;
    for (final e in _situacaoLabels.entries) {
      if (e.value.toLowerCase() == valor.toLowerCase()) return e.key;
    }
    _situacaoLabels[valor] = valor;
    return valor;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true); // Começa o loading

      try {
        final teste = Teste(
          id: widget.testeExistente?.id,
          projetoId: widget.projetoId,
          nome: _nomeController.text,
          descricao: _descricaoController.text,
          situacao: _situacao,
        );

        // Tenta salvar
        await widget.onSave(teste);
        
        // Se deu certo, fecha o modal
        if (mounted) {
          Navigator.pop(context); 
        }
        
      } catch (e) {
        // SE DEU ERRO: Para o loading e mostra mensagem
        if (mounted) {
          setState(() => _isSaving = false);
          avisar(context, 'Erro ao salvar: $e', tipo: TipoAviso.erro);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final novo = widget.testeExistente == null;
    return PainelIdv(
      titulo: novo ? 'Novo teste' : 'Editar teste',
      rotuloAcao: novo ? 'Criar teste' : 'Salvar alterações',
      carregando: _isSaving,
      aoConfirmar: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoIdv(
              rotulo: 'Nome do teste',
              controle: _nomeController,
              obrigatorio: true,
              dica: 'Ex.: Login com e-mail inválido',
            ),
            CampoIdv(
              rotulo: 'Descrição / critérios',
              controle: _descricaoController,
              linhas: 4,
              dica: 'O que deve acontecer para o teste passar',
            ),
            const RotuloIdv('Situação'),
            SelecaoIdv<String>(
              hint: 'Selecione a situação',
              valor: _situacao,
              itens: _situacaoLabels.keys.toList(),
              rotulo: (k) => _situacaoLabels[k]!,
              aoMudar: (v) {
                if (v != null) setState(() => _situacao = v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
