import 'package:flutter/material.dart' show ThemeMode;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'empresa.freezed.dart';

/// Modo de tema da app, guardado por empresa.
enum TemaApp {
  sistema,
  claro,
  escuro;

  static TemaApp fromApi(String? v) => TemaApp.values.firstWhere(
        (t) => t.name == v,
        orElse: () => TemaApp.sistema,
      );

  String get api => name;

  String get label => switch (this) {
        TemaApp.sistema => 'Automático',
        TemaApp.claro => 'Claro',
        TemaApp.escuro => 'Escuro',
      };

  ThemeMode get modo => switch (this) {
        TemaApp.sistema => ThemeMode.system,
        TemaApp.claro => ThemeMode.light,
        TemaApp.escuro => ThemeMode.dark,
      };
}

enum Moeda {
  eur('EUR', '€'),
  brl('BRL', 'R\$'),
  usd('USD', '\$'),
  gbp('GBP', '£');

  const Moeda(this.code, this.symbol);
  final String code;
  final String symbol;

  static Moeda fromCode(String? code) => Moeda.values.firstWhere(
        (m) => m.code == code,
        orElse: () => Moeda.eur,
      );
}

enum RegraArredondamento {
  cima,
  normal;

  static RegraArredondamento fromName(String? name) =>
      RegraArredondamento.values.firstWhere(
        (r) => r.name == name,
        orElse: () => RegraArredondamento.cima,
      );
}

@freezed
class Empresa with _$Empresa {
  const factory Empresa({
    required String id,
    required String nome,
    required String slug,
    required Moeda moeda,
    required RegraArredondamento regraArredondamento,
    @Default('') String corMarca,
    @Default('') String plano,
    @Default(TemaApp.sistema) TemaApp tema,
    @Default('') String logo,
  }) = _Empresa;

  const Empresa._();

  bool get temLogo => logo.isNotEmpty;

  factory Empresa.fromRecord(RecordModel r) => Empresa(
        id: r.id,
        nome: r.getStringValue('nome'),
        slug: r.getStringValue('slug'),
        moeda: Moeda.fromCode(r.getStringValue('moeda')),
        regraArredondamento:
            RegraArredondamento.fromName(r.getStringValue('regra_arredondamento')),
        corMarca: r.getStringValue('cor_marca'),
        plano: r.getStringValue('plano'),
        tema: TemaApp.fromApi(r.getStringValue('tema')),
        logo: r.getStringValue('logo'),
      );
}
