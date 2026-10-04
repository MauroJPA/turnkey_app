// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tech_sheet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$FichaTecnica {
  String get id => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  String get categoria => throw _privateConstructorUsedError;
  double get custoProduto => throw _privateConstructorUsedError;
  double get pesoProduto => throw _privateConstructorUsedError;
  double get precoVenda => throw _privateConstructorUsedError;
  bool get deletado => throw _privateConstructorUsedError;
  String get formatoId => throw _privateConstructorUsedError;
  String get descricao => throw _privateConstructorUsedError;
  String get subnome => throw _privateConstructorUsedError;
  int get validadeDias => throw _privateConstructorUsedError;

  /// Minutos no forno (0 = não definido); aparece na montagem do produto
  /// e dá o cronómetro da fornada na contagem diária.
  int get tempoAssaduraMin => throw _privateConstructorUsedError;
  String get conservacao => throw _privateConstructorUsedError;
  Map<String, dynamic> get nutriRaw => throw _privateConstructorUsedError;
  List<String> get nomesVenda => throw _privateConstructorUsedError;
  bool get custoCompleto => throw _privateConstructorUsedError;
  List<({String id, String nome})> get custoSemDados =>
      throw _privateConstructorUsedError;

  /// Create a copy of FichaTecnica
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FichaTecnicaCopyWith<FichaTecnica> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FichaTecnicaCopyWith<$Res> {
  factory $FichaTecnicaCopyWith(
    FichaTecnica value,
    $Res Function(FichaTecnica) then,
  ) = _$FichaTecnicaCopyWithImpl<$Res, FichaTecnica>;
  @useResult
  $Res call({
    String id,
    String nome,
    String categoria,
    double custoProduto,
    double pesoProduto,
    double precoVenda,
    bool deletado,
    String formatoId,
    String descricao,
    String subnome,
    int validadeDias,
    int tempoAssaduraMin,
    String conservacao,
    Map<String, dynamic> nutriRaw,
    List<String> nomesVenda,
    bool custoCompleto,
    List<({String id, String nome})> custoSemDados,
  });
}

/// @nodoc
class _$FichaTecnicaCopyWithImpl<$Res, $Val extends FichaTecnica>
    implements $FichaTecnicaCopyWith<$Res> {
  _$FichaTecnicaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FichaTecnica
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? categoria = null,
    Object? custoProduto = null,
    Object? pesoProduto = null,
    Object? precoVenda = null,
    Object? deletado = null,
    Object? formatoId = null,
    Object? descricao = null,
    Object? subnome = null,
    Object? validadeDias = null,
    Object? tempoAssaduraMin = null,
    Object? conservacao = null,
    Object? nutriRaw = null,
    Object? nomesVenda = null,
    Object? custoCompleto = null,
    Object? custoSemDados = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            nome: null == nome
                ? _value.nome
                : nome // ignore: cast_nullable_to_non_nullable
                      as String,
            categoria: null == categoria
                ? _value.categoria
                : categoria // ignore: cast_nullable_to_non_nullable
                      as String,
            custoProduto: null == custoProduto
                ? _value.custoProduto
                : custoProduto // ignore: cast_nullable_to_non_nullable
                      as double,
            pesoProduto: null == pesoProduto
                ? _value.pesoProduto
                : pesoProduto // ignore: cast_nullable_to_non_nullable
                      as double,
            precoVenda: null == precoVenda
                ? _value.precoVenda
                : precoVenda // ignore: cast_nullable_to_non_nullable
                      as double,
            deletado: null == deletado
                ? _value.deletado
                : deletado // ignore: cast_nullable_to_non_nullable
                      as bool,
            formatoId: null == formatoId
                ? _value.formatoId
                : formatoId // ignore: cast_nullable_to_non_nullable
                      as String,
            descricao: null == descricao
                ? _value.descricao
                : descricao // ignore: cast_nullable_to_non_nullable
                      as String,
            subnome: null == subnome
                ? _value.subnome
                : subnome // ignore: cast_nullable_to_non_nullable
                      as String,
            validadeDias: null == validadeDias
                ? _value.validadeDias
                : validadeDias // ignore: cast_nullable_to_non_nullable
                      as int,
            tempoAssaduraMin: null == tempoAssaduraMin
                ? _value.tempoAssaduraMin
                : tempoAssaduraMin // ignore: cast_nullable_to_non_nullable
                      as int,
            conservacao: null == conservacao
                ? _value.conservacao
                : conservacao // ignore: cast_nullable_to_non_nullable
                      as String,
            nutriRaw: null == nutriRaw
                ? _value.nutriRaw
                : nutriRaw // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            nomesVenda: null == nomesVenda
                ? _value.nomesVenda
                : nomesVenda // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            custoCompleto: null == custoCompleto
                ? _value.custoCompleto
                : custoCompleto // ignore: cast_nullable_to_non_nullable
                      as bool,
            custoSemDados: null == custoSemDados
                ? _value.custoSemDados
                : custoSemDados // ignore: cast_nullable_to_non_nullable
                      as List<({String id, String nome})>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FichaTecnicaImplCopyWith<$Res>
    implements $FichaTecnicaCopyWith<$Res> {
  factory _$$FichaTecnicaImplCopyWith(
    _$FichaTecnicaImpl value,
    $Res Function(_$FichaTecnicaImpl) then,
  ) = __$$FichaTecnicaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String nome,
    String categoria,
    double custoProduto,
    double pesoProduto,
    double precoVenda,
    bool deletado,
    String formatoId,
    String descricao,
    String subnome,
    int validadeDias,
    int tempoAssaduraMin,
    String conservacao,
    Map<String, dynamic> nutriRaw,
    List<String> nomesVenda,
    bool custoCompleto,
    List<({String id, String nome})> custoSemDados,
  });
}

/// @nodoc
class __$$FichaTecnicaImplCopyWithImpl<$Res>
    extends _$FichaTecnicaCopyWithImpl<$Res, _$FichaTecnicaImpl>
    implements _$$FichaTecnicaImplCopyWith<$Res> {
  __$$FichaTecnicaImplCopyWithImpl(
    _$FichaTecnicaImpl _value,
    $Res Function(_$FichaTecnicaImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FichaTecnica
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? categoria = null,
    Object? custoProduto = null,
    Object? pesoProduto = null,
    Object? precoVenda = null,
    Object? deletado = null,
    Object? formatoId = null,
    Object? descricao = null,
    Object? subnome = null,
    Object? validadeDias = null,
    Object? tempoAssaduraMin = null,
    Object? conservacao = null,
    Object? nutriRaw = null,
    Object? nomesVenda = null,
    Object? custoCompleto = null,
    Object? custoSemDados = null,
  }) {
    return _then(
      _$FichaTecnicaImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        nome: null == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String,
        categoria: null == categoria
            ? _value.categoria
            : categoria // ignore: cast_nullable_to_non_nullable
                  as String,
        custoProduto: null == custoProduto
            ? _value.custoProduto
            : custoProduto // ignore: cast_nullable_to_non_nullable
                  as double,
        pesoProduto: null == pesoProduto
            ? _value.pesoProduto
            : pesoProduto // ignore: cast_nullable_to_non_nullable
                  as double,
        precoVenda: null == precoVenda
            ? _value.precoVenda
            : precoVenda // ignore: cast_nullable_to_non_nullable
                  as double,
        deletado: null == deletado
            ? _value.deletado
            : deletado // ignore: cast_nullable_to_non_nullable
                  as bool,
        formatoId: null == formatoId
            ? _value.formatoId
            : formatoId // ignore: cast_nullable_to_non_nullable
                  as String,
        descricao: null == descricao
            ? _value.descricao
            : descricao // ignore: cast_nullable_to_non_nullable
                  as String,
        subnome: null == subnome
            ? _value.subnome
            : subnome // ignore: cast_nullable_to_non_nullable
                  as String,
        validadeDias: null == validadeDias
            ? _value.validadeDias
            : validadeDias // ignore: cast_nullable_to_non_nullable
                  as int,
        tempoAssaduraMin: null == tempoAssaduraMin
            ? _value.tempoAssaduraMin
            : tempoAssaduraMin // ignore: cast_nullable_to_non_nullable
                  as int,
        conservacao: null == conservacao
            ? _value.conservacao
            : conservacao // ignore: cast_nullable_to_non_nullable
                  as String,
        nutriRaw: null == nutriRaw
            ? _value._nutriRaw
            : nutriRaw // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        nomesVenda: null == nomesVenda
            ? _value._nomesVenda
            : nomesVenda // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        custoCompleto: null == custoCompleto
            ? _value.custoCompleto
            : custoCompleto // ignore: cast_nullable_to_non_nullable
                  as bool,
        custoSemDados: null == custoSemDados
            ? _value._custoSemDados
            : custoSemDados // ignore: cast_nullable_to_non_nullable
                  as List<({String id, String nome})>,
      ),
    );
  }
}

/// @nodoc

class _$FichaTecnicaImpl extends _FichaTecnica {
  const _$FichaTecnicaImpl({
    required this.id,
    required this.nome,
    this.categoria = '',
    this.custoProduto = 0,
    this.pesoProduto = 0,
    this.precoVenda = 0,
    this.deletado = false,
    this.formatoId = '',
    this.descricao = '',
    this.subnome = '',
    this.validadeDias = 0,
    this.tempoAssaduraMin = 0,
    this.conservacao = '',
    final Map<String, dynamic> nutriRaw = const <String, dynamic>{},
    final List<String> nomesVenda = const <String>[],
    this.custoCompleto = true,
    final List<({String id, String nome})> custoSemDados =
        const <({String id, String nome})>[],
  }) : _nutriRaw = nutriRaw,
       _nomesVenda = nomesVenda,
       _custoSemDados = custoSemDados,
       super._();

  @override
  final String id;
  @override
  final String nome;
  @override
  @JsonKey()
  final String categoria;
  @override
  @JsonKey()
  final double custoProduto;
  @override
  @JsonKey()
  final double pesoProduto;
  @override
  @JsonKey()
  final double precoVenda;
  @override
  @JsonKey()
  final bool deletado;
  @override
  @JsonKey()
  final String formatoId;
  @override
  @JsonKey()
  final String descricao;
  @override
  @JsonKey()
  final String subnome;
  @override
  @JsonKey()
  final int validadeDias;

  /// Minutos no forno (0 = não definido); aparece na montagem do produto
  /// e dá o cronómetro da fornada na contagem diária.
  @override
  @JsonKey()
  final int tempoAssaduraMin;
  @override
  @JsonKey()
  final String conservacao;
  final Map<String, dynamic> _nutriRaw;
  @override
  @JsonKey()
  Map<String, dynamic> get nutriRaw {
    if (_nutriRaw is EqualUnmodifiableMapView) return _nutriRaw;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_nutriRaw);
  }

  final List<String> _nomesVenda;
  @override
  @JsonKey()
  List<String> get nomesVenda {
    if (_nomesVenda is EqualUnmodifiableListView) return _nomesVenda;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_nomesVenda);
  }

  @override
  @JsonKey()
  final bool custoCompleto;
  final List<({String id, String nome})> _custoSemDados;
  @override
  @JsonKey()
  List<({String id, String nome})> get custoSemDados {
    if (_custoSemDados is EqualUnmodifiableListView) return _custoSemDados;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_custoSemDados);
  }

  @override
  String toString() {
    return 'FichaTecnica(id: $id, nome: $nome, categoria: $categoria, custoProduto: $custoProduto, pesoProduto: $pesoProduto, precoVenda: $precoVenda, deletado: $deletado, formatoId: $formatoId, descricao: $descricao, subnome: $subnome, validadeDias: $validadeDias, tempoAssaduraMin: $tempoAssaduraMin, conservacao: $conservacao, nutriRaw: $nutriRaw, nomesVenda: $nomesVenda, custoCompleto: $custoCompleto, custoSemDados: $custoSemDados)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FichaTecnicaImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.categoria, categoria) ||
                other.categoria == categoria) &&
            (identical(other.custoProduto, custoProduto) ||
                other.custoProduto == custoProduto) &&
            (identical(other.pesoProduto, pesoProduto) ||
                other.pesoProduto == pesoProduto) &&
            (identical(other.precoVenda, precoVenda) ||
                other.precoVenda == precoVenda) &&
            (identical(other.deletado, deletado) ||
                other.deletado == deletado) &&
            (identical(other.formatoId, formatoId) ||
                other.formatoId == formatoId) &&
            (identical(other.descricao, descricao) ||
                other.descricao == descricao) &&
            (identical(other.subnome, subnome) || other.subnome == subnome) &&
            (identical(other.validadeDias, validadeDias) ||
                other.validadeDias == validadeDias) &&
            (identical(other.tempoAssaduraMin, tempoAssaduraMin) ||
                other.tempoAssaduraMin == tempoAssaduraMin) &&
            (identical(other.conservacao, conservacao) ||
                other.conservacao == conservacao) &&
            const DeepCollectionEquality().equals(other._nutriRaw, _nutriRaw) &&
            const DeepCollectionEquality().equals(
              other._nomesVenda,
              _nomesVenda,
            ) &&
            (identical(other.custoCompleto, custoCompleto) ||
                other.custoCompleto == custoCompleto) &&
            const DeepCollectionEquality().equals(
              other._custoSemDados,
              _custoSemDados,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    nome,
    categoria,
    custoProduto,
    pesoProduto,
    precoVenda,
    deletado,
    formatoId,
    descricao,
    subnome,
    validadeDias,
    tempoAssaduraMin,
    conservacao,
    const DeepCollectionEquality().hash(_nutriRaw),
    const DeepCollectionEquality().hash(_nomesVenda),
    custoCompleto,
    const DeepCollectionEquality().hash(_custoSemDados),
  );

  /// Create a copy of FichaTecnica
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FichaTecnicaImplCopyWith<_$FichaTecnicaImpl> get copyWith =>
      __$$FichaTecnicaImplCopyWithImpl<_$FichaTecnicaImpl>(this, _$identity);
}

abstract class _FichaTecnica extends FichaTecnica {
  const factory _FichaTecnica({
    required final String id,
    required final String nome,
    final String categoria,
    final double custoProduto,
    final double pesoProduto,
    final double precoVenda,
    final bool deletado,
    final String formatoId,
    final String descricao,
    final String subnome,
    final int validadeDias,
    final int tempoAssaduraMin,
    final String conservacao,
    final Map<String, dynamic> nutriRaw,
    final List<String> nomesVenda,
    final bool custoCompleto,
    final List<({String id, String nome})> custoSemDados,
  }) = _$FichaTecnicaImpl;
  const _FichaTecnica._() : super._();

  @override
  String get id;
  @override
  String get nome;
  @override
  String get categoria;
  @override
  double get custoProduto;
  @override
  double get pesoProduto;
  @override
  double get precoVenda;
  @override
  bool get deletado;
  @override
  String get formatoId;
  @override
  String get descricao;
  @override
  String get subnome;
  @override
  int get validadeDias;
  @override
  int get tempoAssaduraMin;
  @override
  String get conservacao;
  @override
  Map<String, dynamic> get nutriRaw;
  @override
  List<String> get nomesVenda;
  @override
  bool get custoCompleto;
  @override
  List<({String id, String nome})> get custoSemDados;

  /// Create a copy of FichaTecnica
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FichaTecnicaImplCopyWith<_$FichaTecnicaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
