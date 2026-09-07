// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recipe.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Receita {
  String get id => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  CategoriaReceita get categoria => throw _privateConstructorUsedError;
  double get rendimentoEsperado => throw _privateConstructorUsedError;
  bool get rendimentoManual => throw _privateConstructorUsedError;
  double get custoReceita => throw _privateConstructorUsedError;
  double get custoPorGrama => throw _privateConstructorUsedError;
  bool get publicarComoIngrediente => throw _privateConstructorUsedError;
  bool get deletado => throw _privateConstructorUsedError;

  /// Create a copy of Receita
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReceitaCopyWith<Receita> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReceitaCopyWith<$Res> {
  factory $ReceitaCopyWith(Receita value, $Res Function(Receita) then) =
      _$ReceitaCopyWithImpl<$Res, Receita>;
  @useResult
  $Res call({
    String id,
    String nome,
    CategoriaReceita categoria,
    double rendimentoEsperado,
    bool rendimentoManual,
    double custoReceita,
    double custoPorGrama,
    bool publicarComoIngrediente,
    bool deletado,
  });
}

/// @nodoc
class _$ReceitaCopyWithImpl<$Res, $Val extends Receita>
    implements $ReceitaCopyWith<$Res> {
  _$ReceitaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Receita
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? categoria = null,
    Object? rendimentoEsperado = null,
    Object? rendimentoManual = null,
    Object? custoReceita = null,
    Object? custoPorGrama = null,
    Object? publicarComoIngrediente = null,
    Object? deletado = null,
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
                      as CategoriaReceita,
            rendimentoEsperado: null == rendimentoEsperado
                ? _value.rendimentoEsperado
                : rendimentoEsperado // ignore: cast_nullable_to_non_nullable
                      as double,
            rendimentoManual: null == rendimentoManual
                ? _value.rendimentoManual
                : rendimentoManual // ignore: cast_nullable_to_non_nullable
                      as bool,
            custoReceita: null == custoReceita
                ? _value.custoReceita
                : custoReceita // ignore: cast_nullable_to_non_nullable
                      as double,
            custoPorGrama: null == custoPorGrama
                ? _value.custoPorGrama
                : custoPorGrama // ignore: cast_nullable_to_non_nullable
                      as double,
            publicarComoIngrediente: null == publicarComoIngrediente
                ? _value.publicarComoIngrediente
                : publicarComoIngrediente // ignore: cast_nullable_to_non_nullable
                      as bool,
            deletado: null == deletado
                ? _value.deletado
                : deletado // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReceitaImplCopyWith<$Res> implements $ReceitaCopyWith<$Res> {
  factory _$$ReceitaImplCopyWith(
    _$ReceitaImpl value,
    $Res Function(_$ReceitaImpl) then,
  ) = __$$ReceitaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String nome,
    CategoriaReceita categoria,
    double rendimentoEsperado,
    bool rendimentoManual,
    double custoReceita,
    double custoPorGrama,
    bool publicarComoIngrediente,
    bool deletado,
  });
}

/// @nodoc
class __$$ReceitaImplCopyWithImpl<$Res>
    extends _$ReceitaCopyWithImpl<$Res, _$ReceitaImpl>
    implements _$$ReceitaImplCopyWith<$Res> {
  __$$ReceitaImplCopyWithImpl(
    _$ReceitaImpl _value,
    $Res Function(_$ReceitaImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Receita
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? categoria = null,
    Object? rendimentoEsperado = null,
    Object? rendimentoManual = null,
    Object? custoReceita = null,
    Object? custoPorGrama = null,
    Object? publicarComoIngrediente = null,
    Object? deletado = null,
  }) {
    return _then(
      _$ReceitaImpl(
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
                  as CategoriaReceita,
        rendimentoEsperado: null == rendimentoEsperado
            ? _value.rendimentoEsperado
            : rendimentoEsperado // ignore: cast_nullable_to_non_nullable
                  as double,
        rendimentoManual: null == rendimentoManual
            ? _value.rendimentoManual
            : rendimentoManual // ignore: cast_nullable_to_non_nullable
                  as bool,
        custoReceita: null == custoReceita
            ? _value.custoReceita
            : custoReceita // ignore: cast_nullable_to_non_nullable
                  as double,
        custoPorGrama: null == custoPorGrama
            ? _value.custoPorGrama
            : custoPorGrama // ignore: cast_nullable_to_non_nullable
                  as double,
        publicarComoIngrediente: null == publicarComoIngrediente
            ? _value.publicarComoIngrediente
            : publicarComoIngrediente // ignore: cast_nullable_to_non_nullable
                  as bool,
        deletado: null == deletado
            ? _value.deletado
            : deletado // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ReceitaImpl extends _Receita {
  const _$ReceitaImpl({
    required this.id,
    required this.nome,
    required this.categoria,
    this.rendimentoEsperado = 0,
    this.rendimentoManual = false,
    this.custoReceita = 0,
    this.custoPorGrama = 0,
    this.publicarComoIngrediente = false,
    this.deletado = false,
  }) : super._();

  @override
  final String id;
  @override
  final String nome;
  @override
  final CategoriaReceita categoria;
  @override
  @JsonKey()
  final double rendimentoEsperado;
  @override
  @JsonKey()
  final bool rendimentoManual;
  @override
  @JsonKey()
  final double custoReceita;
  @override
  @JsonKey()
  final double custoPorGrama;
  @override
  @JsonKey()
  final bool publicarComoIngrediente;
  @override
  @JsonKey()
  final bool deletado;

  @override
  String toString() {
    return 'Receita(id: $id, nome: $nome, categoria: $categoria, rendimentoEsperado: $rendimentoEsperado, rendimentoManual: $rendimentoManual, custoReceita: $custoReceita, custoPorGrama: $custoPorGrama, publicarComoIngrediente: $publicarComoIngrediente, deletado: $deletado)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReceitaImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.categoria, categoria) ||
                other.categoria == categoria) &&
            (identical(other.rendimentoEsperado, rendimentoEsperado) ||
                other.rendimentoEsperado == rendimentoEsperado) &&
            (identical(other.rendimentoManual, rendimentoManual) ||
                other.rendimentoManual == rendimentoManual) &&
            (identical(other.custoReceita, custoReceita) ||
                other.custoReceita == custoReceita) &&
            (identical(other.custoPorGrama, custoPorGrama) ||
                other.custoPorGrama == custoPorGrama) &&
            (identical(
                  other.publicarComoIngrediente,
                  publicarComoIngrediente,
                ) ||
                other.publicarComoIngrediente == publicarComoIngrediente) &&
            (identical(other.deletado, deletado) ||
                other.deletado == deletado));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    nome,
    categoria,
    rendimentoEsperado,
    rendimentoManual,
    custoReceita,
    custoPorGrama,
    publicarComoIngrediente,
    deletado,
  );

  /// Create a copy of Receita
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReceitaImplCopyWith<_$ReceitaImpl> get copyWith =>
      __$$ReceitaImplCopyWithImpl<_$ReceitaImpl>(this, _$identity);
}

abstract class _Receita extends Receita {
  const factory _Receita({
    required final String id,
    required final String nome,
    required final CategoriaReceita categoria,
    final double rendimentoEsperado,
    final bool rendimentoManual,
    final double custoReceita,
    final double custoPorGrama,
    final bool publicarComoIngrediente,
    final bool deletado,
  }) = _$ReceitaImpl;
  const _Receita._() : super._();

  @override
  String get id;
  @override
  String get nome;
  @override
  CategoriaReceita get categoria;
  @override
  double get rendimentoEsperado;
  @override
  bool get rendimentoManual;
  @override
  double get custoReceita;
  @override
  double get custoPorGrama;
  @override
  bool get publicarComoIngrediente;
  @override
  bool get deletado;

  /// Create a copy of Receita
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReceitaImplCopyWith<_$ReceitaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
