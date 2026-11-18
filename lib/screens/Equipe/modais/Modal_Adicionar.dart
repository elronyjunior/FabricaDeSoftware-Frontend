import 'package:fabrica_software_app/Widgets/Modal_de_criacao/components/painel_idv.dart';
import 'package:flutter/material.dart';
import 'package:fabrica_software_app/providers/equipes_provider.dart';
import 'package:fabrica_software_app/models/contribuidor.dart';

class ModalAdicionarPessoa extends StatefulWidget {
  final EquipesProvider provider;
  final Contribuidor? contribuidorParaEditar; // Se vier preenchido, é EDIÇÃO

  const ModalAdicionarPessoa({
    super.key, 
    required this.provider, 
    this.contribuidorParaEditar
  });

  @override
  State<ModalAdicionarPessoa> createState() => _ModalAdicionarPessoaState();
}

class _ModalAdicionarPessoaState extends State<ModalAdicionarPessoa> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _cargoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Se for edição, preenche os campos com os dados existentes
    if (widget.contribuidorParaEditar != null) {
      _nomeController.text = widget.contribuidorParaEditar!.nome;
      _emailController.text = widget.contribuidorParaEditar!.email;
      _cargoController.text = widget.contribuidorParaEditar!.cargo ?? '';
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _cargoController.dispose();
    super.dispose();
  }

  bool _salvando = false;

  Future<void> _salvar() async {
    final isEditing = widget.contribuidorParaEditar != null;
    if (_formKey.currentState!.validate()) {
      setState(() => _salvando = true);
      try {
        if (isEditing) {
          // --- LÓGICA DE ATUALIZAR (CORRIGIDA) ---
          await widget.provider.atualizarContribuidor(
            widget.contribuidorParaEditar!.id!, // ID original
            _nomeController.text,
            _emailController.text,
            _cargoController.text,
          );
        } else {
          // --- LÓGICA DE CRIAR ---
          await widget.provider.criarContribuidor(
            _nomeController.text,
            _emailController.text,
            _cargoController.text,
          );
        }

        // Fecha o modal se tudo der certo
        if (mounted) Navigator.pop(context);
      } catch (e) {
        // Se der erro, mostra um aviso (opcional)
        print("Erro ao salvar: $e");
      } finally {
        if (mounted) setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contribuidorParaEditar != null;

    return PainelIdv(
      titulo: isEditing ? 'Editar pessoa' : 'Nova pessoa',
      rotuloAcao: isEditing ? 'Salvar alterações' : 'Adicionar pessoa',
      carregando: _salvando,
      aoConfirmar: _salvar,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoIdv(
              rotulo: 'Nome completo',
              controle: _nomeController,
              obrigatorio: true,
              dica: 'Nome da pessoa',
            ),
            CampoIdv(
              rotulo: 'E-mail',
              controle: _emailController,
              obrigatorio: true,
              dica: 'nome@empresa.com',
              teclado: TextInputType.emailAddress,
            ),
            CampoIdv(
              rotulo: 'Cargo / função',
              controle: _cargoController,
              obrigatorio: true,
              dica: 'Ex.: Desenvolvedor Front-end',
            ),
          ],
        ),
      ),
    );
  }
}
