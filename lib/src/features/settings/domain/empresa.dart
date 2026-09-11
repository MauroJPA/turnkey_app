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

/// Onde o logótipo/nome da marca aparece na barra superior.
enum Alinhamento {
  esquerda,
  centro,
  direita;

  static Alinhamento fromName(String? name) => Alinhamento.values.firstWhere(
        (a) => a.name == name,
        orElse: () => Alinhamento.esquerda,
      );

  String get label => switch (this) {
        Alinhamento.esquerda => 'Esquerda',
        Alinhamento.centro => 'Centro',
        Alinhamento.direita => 'Direita',
      };
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
    @Default('') String corSecundaria,
    @Default('') String corFundo,
    @Default('') String corTexto,
    @Default(false) bool logoOculto,
    @Default(Alinhamento.esquerda) Alinhamento logoAlinhamento,
    @Default(28) double logoTamanho,
    @Default(false) bool nomeOculto,
    @Default(Alinhamento.esquerda) Alinhamento nomeAlinhamento,
    @Default(18) double nomeTamanho,
    @Default('') String fonteFamilia,
    @Default('') String fonteFicheiro,
  }) = _Empresa;

  const Empresa._();

  bool get temLogo => logo.isNotEmpty;
  bool get temFontePersonalizada => fonteFicheiro.isNotEmpty;
  bool get logoVisivel => !logoOculto;
  bool get nomeVisivel => !nomeOculto;

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
        corSecundaria: r.getStringValue('cor_secundaria'),
        corFundo: r.getStringValue('cor_fundo'),
        corTexto: r.getStringValue('cor_texto'),
        logoOculto: r.getBoolValue('logo_oculto'),
        logoAlinhamento: Alinhamento.fromName(r.getStringValue('logo_alinhamento')),
        logoTamanho: r.getDoubleValue('logo_tamanho') > 0
            ? r.getDoubleValue('logo_tamanho')
            : 28,
        nomeOculto: r.getBoolValue('nome_oculto'),
        nomeAlinhamento: Alinhamento.fromName(r.getStringValue('nome_alinhamento')),
        nomeTamanho: r.getDoubleValue('nome_tamanho') > 0
            ? r.getDoubleValue('nome_tamanho')
            : 18,
        fonteFamilia: r.getStringValue('fonte_familia'),
        fonteFicheiro: r.getStringValue('fonte_ficheiro'),
      );
}
