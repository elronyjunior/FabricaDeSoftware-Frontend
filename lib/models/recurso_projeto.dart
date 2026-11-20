// O back-end manda ids bigint como texto ("12"): aceita os dois.
int? _int(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()));

/// Como o recurso é cobrado no projeto.
enum CobrancaRecurso {
  hora('hora', 'Por hora', '/h'),
  mes('mes', 'Por mês', '/mês'),
  unico('unico', 'Valor único', '');

  const CobrancaRecurso(this.valor, this.rotulo, this.sufixo);

  /// Valor gravado no banco (coluna tipo_cobranca).
  final String valor;
  final String rotulo;

  /// Depois do preço: "R$ 35,00/mês".
  final String sufixo;

  static CobrancaRecurso de(dynamic v) => CobrancaRecurso.values.firstWhere(
        (c) => c.valor == v?.toString(),
        orElse: () => CobrancaRecurso.hora,
      );
}

/// Vínculo de um recurso com um projeto: quantas unidades, quanto custa cada
/// uma (por hora, por mês ou valor único) e o período de uso.
///
/// `quantidade` e `tipo_cobranca` dependem de colunas novas no back-end; até
/// existirem, o back-end não as devolve e valem os padrões (1 e por hora),
/// que dão o mesmo custo de antes.
class RecursoProjeto {
  final int recursoId;
  final int projetoId;

  /// Preço de uma unidade na cobrança escolhida (a coluna se chama
  /// custo_hora por ser a única que existia).
  final double? custoHora;
  final DateTime dataAlocacao;
  final DateTime? dataDesalocacao;
  final int quantidade;
  final CobrancaRecurso cobranca;

  RecursoProjeto({
    required this.recursoId,
    required this.projetoId,
    this.custoHora,
    required this.dataAlocacao,
    this.dataDesalocacao,
    this.quantidade = 1,
    this.cobranca = CobrancaRecurso.hora,
  });

  factory RecursoProjeto.fromJson(Map<String, dynamic> json) {
    return RecursoProjeto(
      recursoId: _int(json['recurso_id'])!,
      projetoId: _int(json['projeto_id'])!,
      custoHora: json['custo_hora'] != null
          ? double.parse(json['custo_hora'].toString())
          : null,
      dataAlocacao: DateTime.parse(json['data_alocacao']),
      dataDesalocacao: json['data_desalocacao'] != null
          ? DateTime.parse(json['data_desalocacao'])
          : null,
      quantidade: (_int(json['quantidade']) ?? 1).clamp(1, 1000000),
      cobranca: CobrancaRecurso.de(json['tipo_cobranca']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recurso_id': recursoId,
      'projeto_id': projetoId,
      'custo_hora': custoHora,
      // Colunas do tipo date: só a data (sem fuso, para não mudar de dia).
      'data_alocacao': _data(dataAlocacao),
      'data_desalocacao': dataDesalocacao == null ? null : _data(dataDesalocacao!),
      'quantidade': quantidade,
      'tipo_cobranca': cobranca.valor,
    };
  }

  static String _data(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Custo estimado do vínculo até o fim do período (ou até hoje, se o
  /// período está em aberto):
  /// - por hora: dias × 8 h × valor × quantidade (a conta antiga);
  /// - por mês: meses começados × valor × quantidade;
  /// - valor único: valor × quantidade.
  double custoEstimado() {
    final valor = (custoHora ?? 0) * quantidade;
    final fim = dataDesalocacao ?? DateTime.now();
    final dias = fim.difference(dataAlocacao).inDays.clamp(0, 100000);
    return switch (cobranca) {
      CobrancaRecurso.hora => dias * 8 * valor,
      CobrancaRecurso.mes => (dias / 30).ceil().clamp(1, 100000) * valor,
      CobrancaRecurso.unico => valor,
    };
  }

  RecursoProjeto copyWith({
    int? recursoId,
    int? projetoId,
    double? custoHora,
    DateTime? dataAlocacao,
    DateTime? dataDesalocacao,
    int? quantidade,
    CobrancaRecurso? cobranca,
  }) {
    return RecursoProjeto(
      recursoId: recursoId ?? this.recursoId,
      projetoId: projetoId ?? this.projetoId,
      custoHora: custoHora ?? this.custoHora,
      dataAlocacao: dataAlocacao ?? this.dataAlocacao,
      dataDesalocacao: dataDesalocacao ?? this.dataDesalocacao,
      quantidade: quantidade ?? this.quantidade,
      cobranca: cobranca ?? this.cobranca,
    );
  }
}
