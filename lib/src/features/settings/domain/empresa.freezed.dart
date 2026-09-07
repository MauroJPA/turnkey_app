// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'empresa.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Empresa {
  String get id => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  String get slug => throw _privateConstructorUsedError;
  Moeda get moeda => throw _privateConstructorUsedError;
  RegraArredondamento get regraArredondamento =>
      throw _privateConstructorUsedError;
  String get corMarca => throw _privateConstructorUsedError;
  String get plano => throw _privateConstructorUsedError;

  /// Create a copy of Empresa
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmpresaCopyWith<Empresa> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmpresaCopyWith<$Res> {
  factory $EmpresaCopyWith(Empresa value, $Res Function(Empresa) then) =
      _$EmpresaCopyWithImpl<$Res, Empresa>;
  @useResult
  $Res call({
    String id,
    String nome,
    String slug,
    Moeda moeda,
    RegraArredondamento regraArredondamento,
    String corMarca,
    String plano,
  });
}

/// @nodoc
class _$EmpresaCopyWithImpl<$Res, $Val extends Empresa>
    implements $EmpresaCopyWith<$Res> {
  _$EmpresaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Empresa
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? slug = null,
    Object? moeda = null,
    Object? regraArredondamento = null,
    Object? corMarca = null,
    Object? plano = null,
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
            slug: null == slug
                ? _value.slug
                : slug // ignore: cast_nullable_to_non_nullable
                      as String,
            moeda: null == moeda
                ? _value.moeda
                : moeda // ignore: cast_nullable_to_non_nullable
                      as Moeda,
            regraArredondamento: null == regraArredondamento
                ? _value.regraArredondamento
                : regraArredondamento // ignore: cast_nullable_to_non_nullable
                      as RegraArredondamento,
            corMarca: null == corMarca
                ? _value.corMarca
                : corMarca // ignore: cast_nullable_to_non_nullable
                      as String,
            plano: null == plano
                ? _value.plano
                : plano // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EmpresaImplCopyWith<$Res> implements $EmpresaCopyWith<$Res> {
  factory _$$EmpresaImplCopyWith(
    _$EmpresaImpl value,
    $Res Function(_$EmpresaImpl) then,
  ) = __$$EmpresaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String nome,
    String slug,
    Moeda moeda,
    RegraArredondamento regraArredondamento,
    String corMarca,
    String plano,
  });
}

/// @nodoc
class __$$EmpresaImplCopyWithImpl<$Res>
    extends _$EmpresaCopyWithImpl<$Res, _$EmpresaImpl>
    implements _$$EmpresaImplCopyWith<$Res> {
  __$$EmpresaImplCopyWithImpl(
    _$EmpresaImpl _value,
    $Res Function(_$EmpresaImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Empresa
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? slug = null,
    Object? moeda = null,
    Object? regraArredondamento = null,
    Object? corMarca = null,
    Object? plano = null,
  }) {
    return _then(
      _$EmpresaImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        nome: null == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String,
        slug: null == slug
            ? _value.slug
            : slug // ignore: cast_nullable_to_non_nullable
                  as String,
        moeda: null == moeda
            ? _value.moeda
            : moeda // ignore: cast_nullable_to_non_nullable
                  as Moeda,
        regraArredondamento: null == regraArredondamento
            ? _value.regraArredondamento
            : regraArredondamento // ignore: cast_nullable_to_non_nullable
                  as RegraArredondamento,
        corMarca: null == corMarca
            ? _value.corMarca
            : corMarca // ignore: cast_nullable_to_non_nullable
                  as String,
        plano: null == plano
            ? _value.plano
            : plano // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$EmpresaImpl extends _Empresa {
  const _$EmpresaImpl({
    required this.id,
    required this.nome,
    required this.slug,
    required this.moeda,
    required this.regraArredondamento,
    this.corMarca = '',
    this.plano = '',
  }) : super._();

  @override
  final String id;
  @override
  final String nome;
  @override
  final String slug;
  @override
  final Moeda moeda;
  @override
  final RegraArredondamento regraArredondamento;
  @override
  @JsonKey()
  final String corMarca;
  @override
  @JsonKey()
  final String plano;

  @override
  String toString() {
    return 'Empresa(id: $id, nome: $nome, slug: $slug, moeda: $moeda, regraArredondamento: $regraArredondamento, corMarca: $corMarca, plano: $plano)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmpresaImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.moeda, moeda) || other.moeda == moeda) &&
            (identical(other.regraArredondamento, regraArredondamento) ||
                other.regraArredondamento == regraArredondamento) &&
            (identical(other.corMarca, corMarca) ||
                other.corMarca == corMarca) &&
            (identical(other.plano, plano) || other.plano == plano));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    nome,
    slug,
    moeda,
    regraArredondamento,
    corMarca,
    plano,
  );

  /// Create a copy of Empresa
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmpresaImplCopyWith<_$EmpresaImpl> get copyWith =>
      __$$EmpresaImplCopyWithImpl<_$EmpresaImpl>(this, _$identity);
}

abstract class _Empresa extends Empresa {
  const factory _Empresa({
    required final String id,
    required final String nome,
    required final String slug,
    required final Moeda moeda,
    required final RegraArredondamento regraArredondamento,
    final String corMarca,
    final String plano,
  }) = _$EmpresaImpl;
  const _Empresa._() : super._();

  @override
  String get id;
  @override
  String get nome;
  @override
  String get slug;
  @override
  Moeda get moeda;
  @override
  RegraArredondamento get regraArredondamento;
  @override
  String get corMarca;
  @override
  String get plano;

  /// Create a copy of Empresa
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmpresaImplCopyWith<_$EmpresaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
