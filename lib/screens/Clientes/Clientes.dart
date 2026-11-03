import 'package:fabrica_software_app/Widgets/Layout_principal/layout_principal.dart';
import 'package:fabrica_software_app/Widgets/Gestao/pagina_gestao.dart';
import 'package:fabrica_software_app/models/cliente.dart';
import 'package:fabrica_software_app/providers/clientes_provider.dart';
import 'package:fabrica_software_app/providers/endereco_provider.dart';
import 'package:fabrica_software_app/providers/projetos_provider.dart';
import 'package:fabrica_software_app/screens/Clientes/components/Cliente_modal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Clientes extends StatefulWidget {
  const Clientes({super.key});

  @override
  State<Clientes> createState() => _ClientesState();
}

class _ClientesState extends State<Clientes> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientesProvider>().carregarClientes();
      // A coluna "Projeto(s)" conta os projetos de cada cliente.
      final projetos = context.read<ProjetosProvider>();
      if (!projetos.projetosCarregados) projetos.carregarProjetos();
    });
  }

  /// 12345678000190 -> 12.345.678/0001-90 (outros formatos ficam como estão).
  static String _cnpj(String valor) {
    final d = valor.replaceAll(RegExp(r'\D'), '');
    if (d.length != 14) return valor;
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/'
        '${d.substring(8, 12)}-${d.substring(12)}';
  }

  @override
  Widget build(BuildContext context) {
    final clientes = context.watch<ClientesProvider>();
    final projetos = context.watch<ProjetosProvider>();

    return ChangeNotifierProvider(
      create: (_) => EnderecosProvider(),
      child: Builder(builder: (ctx) {
        final enderecos = ctx.read<EnderecosProvider>();

        return PaginaGestao<Cliente>(
          titulo: 'Gestão de Clientes',
          rotuloNovo: 'Novo Cliente',
          aoNovo: () => _abrirModalCriarCliente(ctx, enderecos),
          tituloLista: 'Lista de Clientes',
          singular: 'cliente',
          plural: 'clientes',
          itens: clientes.clientes ?? const [],
          carregando: clientes.isLoading,
          erro: clientes.error,
          aoRecarregar: () {
            clientes.carregarClientes();
            projetos.carregarProjetos();
          },
          nome: (c) => c.razaoSocial,
          textoBusca: (c) =>
              '${c.razaoSocial} ${c.cnpj} ${_cnpj(c.cnpj)} ${c.setor ?? ''} ${c.email} ${c.contato ?? ''}',
          rotuloFiltro: 'Setor',
          valorFiltro: (c) =>
              (c.setor ?? '').trim().isEmpty ? null : c.setor!.trim(),
          colunas: const [
            ColunaGestao('Razão social', flex: 4),
            ColunaGestao('CNPJ', flex: 3),
            ColunaGestao('Setor', flex: 2, alinhamento: Alignment.center),
            ColunaGestao('Contato', flex: 4),
            ColunaGestao('Projeto', flex: 2, alinhamento: Alignment.center),
            ColunaGestao('Ações', flex: 2, alinhamento: Alignment.center),
          ],
          celulas: (c) {
            final n = projetos.projetosDoCliente(c.id);
            return [
              NomeComAvatar(c.razaoSocial),
              TextoCelula(_cnpj(c.cnpj)),
              (c.setor ?? '').trim().isEmpty
                  ? const TextoCelula('—', secundario: true)
                  : EtiquetaGestao(c.setor!.trim()),
              TextoCelula(c.email),
              TextoCelula(n == 1 ? '1 Projeto' : '$n Projetos',
                  secundario: n == 0),
            ];
          },
          acoes: (c) => AcoesGestao(
            aoVer: () =>
                _abrirModalCliente(ctx, c, ClienteModalMode.view, enderecos),
            aoEditar: () =>
                _abrirModalCliente(ctx, c, ClienteModalMode.edit, enderecos),
            aoExcluir: () =>
                _abrirModalCliente(ctx, c, ClienteModalMode.delete, enderecos),
          ),
        );
      }),
    );
  }
}

void _abrirModalCliente(BuildContext context, Cliente cliente,
    ClienteModalMode modo, EnderecosProvider provider) {
  mostrarDialogo(
    context: context,
    barrierDismissible: false,
    useRootNavigator: false,
    builder: (ctx) => ClienteModal(
      mode: modo,
      cliente: cliente,
      enderecosProvider: provider,
    ),
  );
}

void _abrirModalCriarCliente(BuildContext context, EnderecosProvider provider) {
  mostrarDialogo(
    context: context,
    barrierDismissible: false,
    useRootNavigator: false,
    builder: (ctx) => ClienteModal(
      mode: ClienteModalMode.create,
      enderecosProvider: provider,
    ),
  );
}
