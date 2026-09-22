import 'package:pocketbase/pocketbase.dart';

/// Tamanho do talão impresso.
enum TalaoTamanho {
  termico80,
  a4;

  static TalaoTamanho fromApi(String? v) =>
      v == 'a4' ? TalaoTamanho.a4 : TalaoTamanho.termico80;

  String get api => name;

  String get label => switch (this) {
        TalaoTamanho.termico80 => 'Térmico (80mm)',
        TalaoTamanho.a4 => 'A4',
      };
}

/// Configuração de encomendas da empresa — tamanho do talão, impressão
/// automática ao criar, e antecedência do lembrete "Encomendas por vir".
/// Sem linha criada ainda (empresa nova), usa-se [vazia] com valores por
/// omissão sensatos — não é preciso nenhum passo extra no onboarding.
class ConfiguracaoEncomendas {
  const ConfiguracaoEncomendas({
    this.id = '',
    this.talaoTamanho = TalaoTamanho.termico80,
    this.imprimirAuto = false,
    this.lembreteHoras = 4,
  });

  final String id;
  final TalaoTamanho talaoTamanho;
  final bool imprimirAuto;

  /// Quantas horas antes de `data_hora` uma encomenda passa a contar como
  /// "por vir" no aviso do Início.
  final double lembreteHoras;

  static const vazia = ConfiguracaoEncomendas();

  factory ConfiguracaoEncomendas.fromRecord(RecordModel r) =>
      ConfiguracaoEncomendas(
        id: r.id,
        talaoTamanho: TalaoTamanho.fromApi(r.getStringValue('talao_tamanho')),
        imprimirAuto: r.getBoolValue('imprimir_auto'),
        lembreteHoras: r.getDoubleValue('lembrete_horas') > 0
            ? r.getDoubleValue('lembrete_horas')
            : 4,
      );
}

/// Dados a gravar (formulário de Configurações).
class ConfiguracaoEncomendasInput {
  ConfiguracaoEncomendasInput({
    required this.talaoTamanho,
    required this.imprimirAuto,
    required this.lembreteHoras,
  });

  final TalaoTamanho talaoTamanho;
  final bool imprimirAuto;
  final double lembreteHoras;

  Map<String, dynamic> toBody() => {
        'talao_tamanho': talaoTamanho.api,
        'imprimir_auto': imprimirAuto,
        'lembrete_horas': lembreteHoras,
      };
}
