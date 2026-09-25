// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recipe_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ItemReceita {
  String get id => throw _privateConstructorUsedError;
  String get receitaId => throw _privateConstructorUsedError;
  String? get ingredienteId => throw _privateConstructorUsedError;
  String? get subReceitaId => throw _privateConstructorUsedError;
  String get nomeProvisorio => throw _privateConstructorUsedError;
  double get quantidadeG => throw _privateConstructorUsedError;
  String get nomeResolvido => throw _privateConstructorUsedError;
  double get custoPorGramaResolvido => throw _privateConstructorUsedError;
  String get ingredienteOrigem => throw _privateConstructorUsedError;
  String? get ingredienteEspelhoId => throw _privateConstructorUsedError;
  String? get produtoId => throw _privateConstructorUsedError;
  String get unidade => throw _privateConstructorUsedError;
  double get fatorPeso => throw _privateConstructorUsedError;

  /// Create a copy of ItemReceita
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ItemReceitaCopyWith<ItemReceita> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ItemReceitaCopyWith<$Res> {
  factory $ItemReceitaCopyWith(
    ItemReceita value,
    $Res Function(ItemReceita) then,
  ) = _$ItemReceitaCopyWithImpl<$Res, ItemReceita>;
  @useResult
  $Res call({
    String id,
    String receitaId,
    String? ingredienteId,
    String? subReceitaId,
    String nomeProvisorio,
    double quantidadeG,
    String nomeResolvido,
    double custoPorGramaResolvido,
    String ingredienteOrigem,
    String? ingredienteEspelhoId,
    String? produtoId,
    String unidade,
    double fatorPeso,
  });
}

/// @nodoc
class _$ItemReceitaCopyWithImpl<$Res, $Val extends ItemReceita>
    implements $ItemReceitaCopyWith<$Res> {
  _$ItemReceitaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ItemReceita
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? receitaId = null,
    Object? ingredienteId = freezed,
    Object? subReceitaId = freezed,
    Object? nomeProvisorio = null,
    Object? quantidadeG = null,
    Object? nomeResolvido = null,
    Object? custoPorGramaResolvido = null,
    Object? ingredienteOrigem = null,
    Object? ingredienteEspelhoId = freezed,
    Object? produtoId = freezed,
    Object? unidade = null,
    Object? fatorPeso = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            receitaId: null == receitaId
                ? _value.receitaId
                : receitaId // ignore: cast_nullable_to_non_nullable
                      as String,
            ingredienteId: freezed == ingredienteId
                ? _value.ingredienteId
                : ingredienteId // ignore: cast_nullable_to_non_nullable
                      as String?,
            subReceitaId: freezed == subReceitaId
                ? _value.subReceitaId
                : subReceitaId // ignore: cast_nullable_to_non_nullable
                      as String?,
            nomeProvisorio: null == nomeProvisorio
                ? _value.nomeProvisorio
                : nomeProvisorio // ignore: cast_nullable_to_non_nullable
                      as String,
            quantidadeG: null == quantidadeG
                ? _value.quantidadeG
                : quantidadeG // ignore: cast_nullable_to_non_nullable
                      as double,
            nomeResolvido: null == nomeResolvido
                ? _value.nomeResolvido
                : nomeResolvido // ignore: cast_nullable_to_non_nullable
                      as String,
            custoPorGramaResolvido: null == custoPorGramaResolvido
                ? _value.custoPorGramaResolvido
                : custoPorGramaResolvido // ignore: cast_nullable_to_non_nullable
                      as double,
            ingredienteOrigem: null == ingredienteOrigem
                ? _value.ingredienteOrigem
                : ingredienteOrigem // ignore: cast_nullable_to_non_nullable
                      as String,
            ingredienteEspelhoId: freezed == ingredienteEspelhoId
                ? _value.ingredienteEspelhoId
                : ingredienteEspelhoId // ignore: cast_nullable_to_non_nullable
                      as String?,
            produtoId: freezed == produtoId
                ? _value.produtoId
                : produtoId // ignore: cast_nullable_to_non_nullable
                      as String?,
            unidade: null == unidade
                ? _value.unidade
                : unidade // ignore: cast_nullable_to_non_nullable
                      as String,
            fatorPeso: null == fatorPeso
                ? _value.fatorPeso
                : fatorPeso // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ItemReceitaImplCopyWith<$Res>
    implements $ItemReceitaCopyWith<$Res> {
  factory _$$ItemReceitaImplCopyWith(
    _$ItemReceitaImpl value,
    $Res Function(_$ItemReceitaImpl) then,
  ) = __$$ItemReceitaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String receitaId,
    String? ingredienteId,
    String? subReceitaId,
    String nomeProvisorio,
    double quantidadeG,
    String nomeResolvido,
    double custoPorGramaResolvido,
    String ingredienteOrigem,
    String? ingredienteEspelhoId,
    String? produtoId,
    String unidade,
    double fatorPeso,
  });
}

/// @nodoc
class __$$ItemReceitaImplCopyWithImpl<$Res>
    extends _$ItemReceitaCopyWithImpl<$Res, _$ItemReceitaImpl>
    implements _$$ItemReceitaImplCopyWith<$Res> {
  __$$ItemReceitaImplCopyWithImpl(
    _$ItemReceitaImpl _value,
    $Res Function(_$ItemReceitaImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ItemReceita
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? receitaId = null,
    Object? ingredienteId = freezed,
    Object? subReceitaId = freezed,
    Object? nomeProvisorio = null,
    Object? quantidadeG = null,
    Object? nomeResolvido = null,
    Object? custoPorGramaResolvido = null,
    Object? ingredienteOrigem = null,
    Object? ingredienteEspelhoId = freezed,
    Object? produtoId = freezed,
    Object? unidade = null,
    Object? fatorPeso = null,
  }) {
    return _then(
      _$ItemReceitaImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        receitaId: null == receitaId
            ? _value.receitaId
            : receitaId // ignore: cast_nullable_to_non_nullable
                  as String,
        ingredienteId: freezed == ingredienteId
            ? _value.ingredienteId
            : ingredienteId // ignore: cast_nullable_to_non_nullable
                  as String?,
        subReceitaId: freezed == subReceitaId
            ? _value.subReceitaId
            : subReceitaId // ignore: cast_nullable_to_non_nullable
                  as String?,
        nomeProvisorio: null == nomeProvisorio
            ? _value.nomeProvisorio
            : nomeProvisorio // ignore: cast_nullable_to_non_nullable
                  as String,
        quantidadeG: null == quantidadeG
            ? _value.quantidadeG
            : quantidadeG // ignore: cast_nullable_to_non_nullable
                  as double,
        nomeResolvido: null == nomeResolvido
            ? _value.nomeResolvido
            : nomeResolvido // ignore: cast_nullable_to_non_nullable
                  as String,
        custoPorGramaResolvido: null == custoPorGramaResolvido
            ? _value.custoPorGramaResolvido
            : custoPorGramaResolvido // ignore: cast_nullable_to_non_nullable
                  as double,
        ingredienteOrigem: null == ingredienteOrigem
            ? _value.ingredienteOrigem
            : ingredienteOrigem // ignore: cast_nullable_to_non_nullable
                  as String,
        ingredienteEspelhoId: freezed == ingredienteEspelhoId
            ? _value.ingredienteEspelhoId
            : ingredienteEspelhoId // ignore: cast_nullable_to_non_nullable
                  as String?,
        produtoId: freezed == produtoId
            ? _value.produtoId
            : produtoId // ignore: cast_nullable_to_non_nullable
                  as String?,
        unidade: null == unidade
            ? _value.unidade
            : unidade // ignore: cast_nullable_to_non_nullable
                  as String,
        fatorPeso: null == fatorPeso
            ? _value.fatorPeso
            : fatorPeso // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$ItemReceitaImpl extends _ItemReceita {
  const _$ItemReceitaImpl({
    required this.id,
    required this.receitaId,
    this.ingredienteId,
    this.subReceitaId,
    this.nomeProvisorio = '',
    this.quantidadeG = 0,
    this.nomeResolvido = '',
    this.custoPorGramaResolvido = 0,
    this.ingredienteOrigem = '',
    this.ingredienteEspelhoId,
    this.produtoId,
    this.unidade = 'g',
    this.fatorPeso = 1,
  }) : super._();

  @override
  final String id;
  @override
  final String receitaId;
  @override
  final String? ingredienteId;
  @override
  final String? subReceitaId;
  @override
  @JsonKey()
  final String nomeProvisorio;
  @override
  @JsonKey()
  final double quantidadeG;
  @override
  @JsonKey()
  final String nomeResolvido;
  @override
  @JsonKey()
  final double custoPorGramaResolvido;
  @override
  @JsonKey()
  final String ingredienteOrigem;
  @override
  final String? ingredienteEspelhoId;
  @override
  final String? produtoId;
  @override
  @JsonKey()
  final String unidade;
  @override
  @JsonKey()
  final double fatorPeso;

  @override
  String toString() {
    return 'ItemReceita(id: $id, receitaId: $receitaId, ingredienteId: $ingredienteId, subReceitaId: $subReceitaId, nomeProvisorio: $nomeProvisorio, quantidadeG: $quantidadeG, nomeResolvido: $nomeResolvido, custoPorGramaResolvido: $custoPorGramaResolvido, ingredienteOrigem: $ingredienteOrigem, ingredienteEspelhoId: $ingredienteEspelhoId, produtoId: $produtoId, unidade: $unidade, fatorPeso: $fatorPeso)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ItemReceitaImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.receitaId, receitaId) ||
                other.receitaId == receitaId) &&
            (identical(other.ingredienteId, ingredienteId) ||
                other.ingredienteId == ingredienteId) &&
            (identical(other.subReceitaId, subReceitaId) ||
                other.subReceitaId == subReceitaId) &&
            (identical(other.nomeProvisorio, nomeProvisorio) ||
                other.nomeProvisorio == nomeProvisorio) &&
            (identical(other.quantidadeG, quantidadeG) ||
                other.quantidadeG == quantidadeG) &&
            (identical(other.nomeResolvido, nomeResolvido) ||
                other.nomeResolvido == nomeResolvido) &&
            (identical(other.custoPorGramaResolvido, custoPorGramaResolvido) ||
                other.custoPorGramaResolvido == custoPorGramaResolvido) &&
            (identical(other.ingredienteOrigem, ingredienteOrigem) ||
                other.ingredienteOrigem == ingredienteOrigem) &&
            (identical(other.ingredienteEspelhoId, ingredienteEspelhoId) ||
                other.ingredienteEspelhoId == ingredienteEspelhoId) &&
            (identical(other.produtoId, produtoId) ||
                other.produtoId == produtoId) &&
            (identical(other.unidade, unidade) || other.unidade == unidade) &&
            (identical(other.fatorPeso, fatorPeso) ||
                other.fatorPeso == fatorPeso));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    receitaId,
    ingredienteId,
    subReceitaId,
    nomeProvisorio,
    quantidadeG,
    nomeResolvido,
    custoPorGramaResolvido,
    ingredienteOrigem,
    ingredienteEspelhoId,
    produtoId,
    unidade,
    fatorPeso,
  );

  /// Create a copy of ItemReceita
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ItemReceitaImplCopyWith<_$ItemReceitaImpl> get copyWith =>
      __$$ItemReceitaImplCopyWithImpl<_$ItemReceitaImpl>(this, _$identity);
}

abstract class _ItemReceita extends ItemReceita {
  const factory _ItemReceita({
    required final String id,
    required final String receitaId,
    final String? ingredienteId,
    final String? subReceitaId,
    final String nomeProvisorio,
    final double quantidadeG,
    final String nomeResolvido,
    final double custoPorGramaResolvido,
    final String ingredienteOrigem,
    final String? ingredienteEspelhoId,
    final String? produtoId,
    final String unidade,
    final double fatorPeso,
  }) = _$ItemReceitaImpl;
  const _ItemReceita._() : super._();

  @override
  String get id;
  @override
  String get receitaId;
  @override
  String? get ingredienteId;
  @override
  String? get subReceitaId;
  @override
  String get nomeProvisorio;
  @override
  double get quantidadeG;
  @override
  String get nomeResolvido;
  @override
  double get custoPorGramaResolvido;
  @override
  String get ingredienteOrigem;
  @override
  String? get ingredienteEspelhoId;
  @override
  String? get produtoId;
  @override
  String get unidade;
  @override
  double get fatorPeso;

  /// Create a copy of ItemReceita
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ItemReceitaImplCopyWith<_$ItemReceitaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
