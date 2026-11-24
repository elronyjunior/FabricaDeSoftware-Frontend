import 'package:fabrica_software_app/Widgets/Gestao/pagina_gestao.dart';
import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/models/recurso.dart';
import 'package:fabrica_software_app/providers/recursos_provider.dart';
import 'package:fabrica_software_app/screens/Recursos/components/Recursos_modal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Cadastro geral de recursos (menu lateral). Um recurso existe sem projeto;
/// os projetos é que o vinculam, cada um com o seu custo/hora e período
/// (ver `recursos_do_projeto.dart`).
class Recursos extends StatefulWidget {
  const Recursos({super.key});

  @override
  State<Recursos> createState() => _RecursosState();
}

class _RecursosState extends State<Recursos> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecursosProvider>().carregarRecursos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecursosProvider>();

    return PaginaGestao<Recurso>(
      titulo: 'Gestão de Recursos',
      rotuloNovo: 'Novo Recurso',
      aoNovo: () => _abrirModalRecurso(context, null, RecursoModalMode.create),
      tituloLista: 'Lista de Recursos',
      singular: 'recurso',
      plural: 'recursos',
      itens: provider.recursos ?? const [],
      carregando: provider.isLoading,
      erro: provider.error,
      aoRecarregar: provider.carregarRecursos,
      nome: (r) => r.nome,
      textoBusca: (r) => '${r.nome} ${r.tipo} ${r.descricao ?? ''}',
      rotuloFiltro: 'Tipo',
      valorFiltro: (r) => r.tipo.trim().isEmpty ? null : r.tipo.trim(),
      colunas: const [
        ColunaGestao('Nome', flex: 4),
        ColunaGestao('Tipo', flex: 2, alinhamento: Alignment.center),
        ColunaGestao('Disponível', flex: 2, alinhamento: Alignment.center),
        ColunaGestao('Descrição', flex: 4),
        ColunaGestao('Projetos', flex: 2, alinhamento: Alignment.center),
        ColunaGestao('Ações', flex: 2, alinhamento: Alignment.center),
      ],
      celulas: (r) {
        final n = provider.usosDe(r.id);
        return [
          NomeComAvatar(r.nome),
          EtiquetaGestao(r.tipo),
          EtiquetaGestao(
            r.disponivel ? 'Disponível' : 'Indisponível',
            fundo: r.disponivel
                ? const Color(0xFF7DC08A)
                : const Color(0x140F1030),
          ),
          TextoCelula(
            (r.descricao ?? '').trim().isEmpty ? '—' : r.descricao!.trim(),
            secundario: (r.descricao ?? '').trim().isEmpty,
          ),
          TextoCelula(n == 1 ? '1 projeto' : '$n projetos', secundario: n == 0),
        ];
      },
      acoes: (r) => AcoesGestao(
        aoVer: () => _abrirModalRecurso(context, r, RecursoModalMode.view),
        aoEditar: () => _abrirModalRecurso(context, r, RecursoModalMode.edit),
        aoExcluir: () => _abrirModalRecurso(context, r, RecursoModalMode.delete),
      ),
    );
  }
}

Future<void> _abrirModalRecurso(
    BuildContext context, Recurso? recurso, RecursoModalMode modo) async {
  final provider = context.read<RecursosProvider>();
  await mostrarDialogo(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => RecursoModal(mode: modo, recurso: recurso),
  );
  // A contagem de projetos muda quando um recurso é excluído.
  if (modo == RecursoModalMode.delete) provider.carregarRecursos();
}
