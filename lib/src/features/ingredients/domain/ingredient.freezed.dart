// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ingredient.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Ingrediente {
  String get id => throw _privateConstructorUsedError;
  String get nome => throw _privateConstructorUsedError;
  String get caracteristica => throw _privateConstructorUsedError;
  String get marca => throw _privateConstructorUsedError;
  String get fornecedor => throw _privateConstructorUsedError;
  double get preco => throw _privateConstructorUsedError;
  double get gramasEmbalagem => throw _privateConstructorUsedError;
  DateTime? get precoAtualizadoEm => throw _privateConstructorUsedError;
  bool get disponivel => throw _privateConstructorUsedError;
  OrigemIngrediente get origem => throw _privateConstructorUsedError;
  bool get deletado =>
      throw _privateConstructorUsedError; // Nutrição (por 100 g/ml) e alergénios — ver core/nutrition.
  Nutrientes get nutri => throw _privateConstructorUsedError;
  String get nutriBase => throw _privateConstructorUsedError;
  double get nutriDensidade => throw _privateConstructorUsedError;
  String get nutriOrigem => throw _privateConstructorUsedError;
  DateTime? get nutriAtualizadoEm => throw _privateConstructorUsedError;
  List<String> get alergenios => throw _privateConstructorUsedError;
  List<String> get alergeniosTracos => throw _privateConstructorUsedError;

  /// Create a copy of Ingrediente
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $IngredienteCopyWith<Ingrediente> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IngredienteCopyWith<$Res> {
  factory $IngredienteCopyWith(
    Ingrediente value,
    $Res Function(Ingrediente) then,
  ) = _$IngredienteCopyWithImpl<$Res, Ingrediente>;
  @useResult
  $Res call({
    String id,
    String nome,
    String caracteristica,
    String marca,
    String fornecedor,
    double preco,
    double gramasEmbalagem,
    DateTime? precoAtualizadoEm,
    bool disponivel,
    OrigemIngrediente origem,
    bool deletado,
    Nutrientes nutri,
    String nutriBase,
    double nutriDensidade,
    String nutriOrigem,
    DateTime? nutriAtualizadoEm,
    List<String> alergenios,
    List<String> alergeniosTracos,
  });
}

/// @nodoc
class _$IngredienteCopyWithImpl<$Res, $Val extends Ingrediente>
    implements $IngredienteCopyWith<$Res> {
  _$IngredienteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Ingrediente
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? caracteristica = null,
    Object? marca = null,
    Object? fornecedor = null,
    Object? preco = null,
    Object? gramasEmbalagem = null,
    Object? precoAtualizadoEm = freezed,
    Object? disponivel = null,
    Object? origem = null,
    Object? deletado = null,
    Object? nutri = null,
    Object? nutriBase = null,
    Object? nutriDensidade = null,
    Object? nutriOrigem = null,
    Object? nutriAtualizadoEm = freezed,
    Object? alergenios = null,
    Object? alergeniosTracos = null,
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
            caracteristica: null == caracteristica
                ? _value.caracteristica
                : caracteristica // ignore: cast_nullable_to_non_nullable
                      as String,
            marca: null == marca
                ? _value.marca
                : marca // ignore: cast_nullable_to_non_nullable
                      as String,
            fornecedor: null == fornecedor
                ? _value.fornecedor
                : fornecedor // ignore: cast_nullable_to_non_nullable
                      as String,
            preco: null == preco
                ? _value.preco
                : preco // ignore: cast_nullable_to_non_nullable
                      as double,
            gramasEmbalagem: null == gramasEmbalagem
                ? _value.gramasEmbalagem
                : gramasEmbalagem // ignore: cast_nullable_to_non_nullable
                      as double,
            precoAtualizadoEm: freezed == precoAtualizadoEm
                ? _value.precoAtualizadoEm
                : precoAtualizadoEm // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            disponivel: null == disponivel
                ? _value.disponivel
                : disponivel // ignore: cast_nullable_to_non_nullable
                      as bool,
            origem: null == origem
                ? _value.origem
                : origem // ignore: cast_nullable_to_non_nullable
                      as OrigemIngrediente,
            deletado: null == deletado
                ? _value.deletado
                : deletado // ignore: cast_nullable_to_non_nullable
                      as bool,
            nutri: null == nutri
                ? _value.nutri
                : nutri // ignore: cast_nullable_to_non_nullable
                      as Nutrientes,
            nutriBase: null == nutriBase
                ? _value.nutriBase
                : nutriBase // ignore: cast_nullable_to_non_nullable
                      as String,
            nutriDensidade: null == nutriDensidade
                ? _value.nutriDensidade
                : nutriDensidade // ignore: cast_nullable_to_non_nullable
                      as double,
            nutriOrigem: null == nutriOrigem
                ? _value.nutriOrigem
                : nutriOrigem // ignore: cast_nullable_to_non_nullable
                      as String,
            nutriAtualizadoEm: freezed == nutriAtualizadoEm
                ? _value.nutriAtualizadoEm
                : nutriAtualizadoEm // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            alergenios: null == alergenios
                ? _value.alergenios
                : alergenios // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            alergeniosTracos: null == alergeniosTracos
                ? _value.alergeniosTracos
                : alergeniosTracos // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$IngredienteImplCopyWith<$Res>
    implements $IngredienteCopyWith<$Res> {
  factory _$$IngredienteImplCopyWith(
    _$IngredienteImpl value,
    $Res Function(_$IngredienteImpl) then,
  ) = __$$IngredienteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String nome,
    String caracteristica,
    String marca,
    String fornecedor,
    double preco,
    double gramasEmbalagem,
    DateTime? precoAtualizadoEm,
    bool disponivel,
    OrigemIngrediente origem,
    bool deletado,
    Nutrientes nutri,
    String nutriBase,
    double nutriDensidade,
    String nutriOrigem,
    DateTime? nutriAtualizadoEm,
    List<String> alergenios,
    List<String> alergeniosTracos,
  });
}

/// @nodoc
class __$$IngredienteImplCopyWithImpl<$Res>
    extends _$IngredienteCopyWithImpl<$Res, _$IngredienteImpl>
    implements _$$IngredienteImplCopyWith<$Res> {
  __$$IngredienteImplCopyWithImpl(
    _$IngredienteImpl _value,
    $Res Function(_$IngredienteImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Ingrediente
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? nome = null,
    Object? caracteristica = null,
    Object? marca = null,
    Object? fornecedor = null,
    Object? preco = null,
    Object? gramasEmbalagem = null,
    Object? precoAtualizadoEm = freezed,
    Object? disponivel = null,
    Object? origem = null,
    Object? deletado = null,
    Object? nutri = null,
    Object? nutriBase = null,
    Object? nutriDensidade = null,
    Object? nutriOrigem = null,
    Object? nutriAtualizadoEm = freezed,
    Object? alergenios = null,
    Object? alergeniosTracos = null,
  }) {
    return _then(
      _$IngredienteImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        nome: null == nome
            ? _value.nome
            : nome // ignore: cast_nullable_to_non_nullable
                  as String,
        caracteristica: null == caracteristica
            ? _value.caracteristica
            : caracteristica // ignore: cast_nullable_to_non_nullable
                  as String,
        marca: null == marca
            ? _value.marca
            : marca // ignore: cast_nullable_to_non_nullable
                  as String,
        fornecedor: null == fornecedor
            ? _value.fornecedor
            : fornecedor // ignore: cast_nullable_to_non_nullable
                  as String,
        preco: null == preco
            ? _value.preco
            : preco // ignore: cast_nullable_to_non_nullable
                  as double,
        gramasEmbalagem: null == gramasEmbalagem
            ? _value.gramasEmbalagem
            : gramasEmbalagem // ignore: cast_nullable_to_non_nullable
                  as double,
        precoAtualizadoEm: freezed == precoAtualizadoEm
            ? _value.precoAtualizadoEm
            : precoAtualizadoEm // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        disponivel: null == disponivel
            ? _value.disponivel
            : disponivel // ignore: cast_nullable_to_non_nullable
                  as bool,
        origem: null == origem
            ? _value.origem
            : origem // ignore: cast_nullable_to_non_nullable
                  as OrigemIngrediente,
        deletado: null == deletado
            ? _value.deletado
            : deletado // ignore: cast_nullable_to_non_nullable
                  as bool,
        nutri: null == nutri
            ? _value.nutri
            : nutri // ignore: cast_nullable_to_non_nullable
                  as Nutrientes,
        nutriBase: null == nutriBase
            ? _value.nutriBase
            : nutriBase // ignore: cast_nullable_to_non_nullable
                  as String,
        nutriDensidade: null == nutriDensidade
            ? _value.nutriDensidade
            : nutriDensidade // ignore: cast_nullable_to_non_nullable
                  as double,
        nutriOrigem: null == nutriOrigem
            ? _value.nutriOrigem
            : nutriOrigem // ignore: cast_nullable_to_non_nullable
                  as String,
        nutriAtualizadoEm: freezed == nutriAtualizadoEm
            ? _value.nutriAtualizadoEm
            : nutriAtualizadoEm // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        alergenios: null == alergenios
            ? _value._alergenios
            : alergenios // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        alergeniosTracos: null == alergeniosTracos
            ? _value._alergeniosTracos
            : alergeniosTracos // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$IngredienteImpl extends _Ingrediente {
  const _$IngredienteImpl({
    required this.id,
    required this.nome,
    this.caracteristica = '',
    this.marca = '',
    this.fornecedor = '',
    this.preco = 0,
    this.gramasEmbalagem = 0,
    this.precoAtualizadoEm,
    this.disponivel = true,
    this.origem = OrigemIngrediente.comprado,
    this.deletado = false,
    this.nutri = const Nutrientes(),
    this.nutriBase = '100g',
    this.nutriDensidade = 1,
    this.nutriOrigem = '',
    this.nutriAtualizadoEm,
    final List<String> alergenios = const <String>[],
    final List<String> alergeniosTracos = const <String>[],
  }) : _alergenios = alergenios,
       _alergeniosTracos = alergeniosTracos,
       super._();

  @override
  final String id;
  @override
  final String nome;
  @override
  @JsonKey()
  final String caracteristica;
  @override
  @JsonKey()
  final String marca;
  @override
  @JsonKey()
  final String fornecedor;
  @override
  @JsonKey()
  final double preco;
  @override
  @JsonKey()
  final double gramasEmbalagem;
  @override
  final DateTime? precoAtualizadoEm;
  @override
  @JsonKey()
  final bool disponivel;
  @override
  @JsonKey()
  final OrigemIngrediente origem;
  @override
  @JsonKey()
  final bool deletado;
  // Nutrição (por 100 g/ml) e alergénios — ver core/nutrition.
  @override
  @JsonKey()
  final Nutrientes nutri;
  @override
  @JsonKey()
  final String nutriBase;
  @override
  @JsonKey()
  final double nutriDensidade;
  @override
  @JsonKey()
  final String nutriOrigem;
  @override
  final DateTime? nutriAtualizadoEm;
  final List<String> _alergenios;
  @override
  @JsonKey()
  List<String> get alergenios {
    if (_alergenios is EqualUnmodifiableListView) return _alergenios;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_alergenios);
  }

  final List<String> _alergeniosTracos;
  @override
  @JsonKey()
  List<String> get alergeniosTracos {
    if (_alergeniosTracos is EqualUnmodifiableListView)
      return _alergeniosTracos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_alergeniosTracos);
  }

  @override
  String toString() {
    return 'Ingrediente(id: $id, nome: $nome, caracteristica: $caracteristica, marca: $marca, fornecedor: $fornecedor, preco: $preco, gramasEmbalagem: $gramasEmbalagem, precoAtualizadoEm: $precoAtualizadoEm, disponivel: $disponivel, origem: $origem, deletado: $deletado, nutri: $nutri, nutriBase: $nutriBase, nutriDensidade: $nutriDensidade, nutriOrigem: $nutriOrigem, nutriAtualizadoEm: $nutriAtualizadoEm, alergenios: $alergenios, alergeniosTracos: $alergeniosTracos)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IngredienteImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nome, nome) || other.nome == nome) &&
            (identical(other.caracteristica, caracteristica) ||
                other.caracteristica == caracteristica) &&
            (identical(other.marca, marca) || other.marca == marca) &&
            (identical(other.fornecedor, fornecedor) ||
                other.fornecedor == fornecedor) &&
            (identical(other.preco, preco) || other.preco == preco) &&
            (identical(other.gramasEmbalagem, gramasEmbalagem) ||
                other.gramasEmbalagem == gramasEmbalagem) &&
            (identical(other.precoAtualizadoEm, precoAtualizadoEm) ||
                other.precoAtualizadoEm == precoAtualizadoEm) &&
            (identical(other.disponivel, disponivel) ||
                other.disponivel == disponivel) &&
            (identical(other.origem, origem) || other.origem == origem) &&
            (identical(other.deletado, deletado) ||
                other.deletado == deletado) &&
            (identical(other.nutri, nutri) || other.nutri == nutri) &&
            (identical(other.nutriBase, nutriBase) ||
                other.nutriBase == nutriBase) &&
            (identical(other.nutriDensidade, nutriDensidade) ||
                other.nutriDensidade == nutriDensidade) &&
            (identical(other.nutriOrigem, nutriOrigem) ||
                other.nutriOrigem == nutriOrigem) &&
            (identical(other.nutriAtualizadoEm, nutriAtualizadoEm) ||
                other.nutriAtualizadoEm == nutriAtualizadoEm) &&
            const DeepCollectionEquality().equals(
              other._alergenios,
              _alergenios,
            ) &&
            const DeepCollectionEquality().equals(
              other._alergeniosTracos,
              _alergeniosTracos,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    nome,
    caracteristica,
    marca,
    fornecedor,
    preco,
    gramasEmbalagem,
    precoAtualizadoEm,
    disponivel,
    origem,
    deletado,
    nutri,
    nutriBase,
    nutriDensidade,
    nutriOrigem,
    nutriAtualizadoEm,
    const DeepCollectionEquality().hash(_alergenios),
    const DeepCollectionEquality().hash(_alergeniosTracos),
  );

  /// Create a copy of Ingrediente
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$IngredienteImplCopyWith<_$IngredienteImpl> get copyWith =>
      __$$IngredienteImplCopyWithImpl<_$IngredienteImpl>(this, _$identity);
}

abstract class _Ingrediente extends Ingrediente {
  const factory _Ingrediente({
    required final String id,
    required final String nome,
    final String caracteristica,
    final String marca,
    final String fornecedor,
    final double preco,
    final double gramasEmbalagem,
    final DateTime? precoAtualizadoEm,
    final bool disponivel,
    final OrigemIngrediente origem,
    final bool deletado,
    final Nutrientes nutri,
    final String nutriBase,
    final double nutriDensidade,
    final String nutriOrigem,
    final DateTime? nutriAtualizadoEm,
    final List<String> alergenios,
    final List<String> alergeniosTracos,
  }) = _$IngredienteImpl;
  const _Ingrediente._() : super._();

  @override
  String get id;
  @override
  String get nome;
  @override
  String get caracteristica;
  @override
  String get marca;
  @override
  String get fornecedor;
  @override
  double get preco;
  @override
  double get gramasEmbalagem;
  @override
  DateTime? get precoAtualizadoEm;
  @override
  bool get disponivel;
  @override
  OrigemIngrediente get origem;
  @override
  bool get deletado; // Nutrição (por 100 g/ml) e alergénios — ver core/nutrition.
  @override
  Nutrientes get nutri;
  @override
  String get nutriBase;
  @override
  double get nutriDensidade;
  @override
  String get nutriOrigem;
  @override
  DateTime? get nutriAtualizadoEm;
  @override
  List<String> get alergenios;
  @override
  List<String> get alergeniosTracos;

  /// Create a copy of Ingrediente
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$IngredienteImplCopyWith<_$IngredienteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
