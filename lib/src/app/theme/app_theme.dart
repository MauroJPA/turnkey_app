import 'package:flutter/material.dart';

/// Tema Material 3 da app — inspirado no vocabulário visual das apps da
/// Apple: cantos bem arredondados, cartões planos com sombra suave em vez de
/// "tint" tonal, campos preenchidos (sem caixas com contorno duro), tipografia
/// com mais peso nos títulos e hierarquia clara entre o fundo e as superfícies
/// elevadas (estilo "grouped list" do iOS: fundo cinza suave, cartões claros).
///
/// A cor de destaque pode ser trocada por empresa (Configurações → Aparência,
/// campo `cor_marca`).
class AppTheme {
  const AppTheme._();

  /// Castanho "cookie" — cor de marca por omissão.
  static const Color seed = Color(0xFF8D5B34);

  /// Cantos: pequeno (campos/chips), médio (botões/cartões), grande
  /// (folhas/diálogos), pílula (cápsulas totalmente arredondadas).
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 24;
  static const double radiusPill = 999;

  /// Cores predefinidas para escolher em Configurações → Aparência — a
  /// mesma lógica da roda de cores do iOS/macOS (um tom vivo por linha).
  static const List<({String nome, Color cor})> presets = [
    (nome: 'Castanho cookie', cor: Color(0xFF8D5B34)),
    (nome: 'Azul', cor: Color(0xFF0A7CFF)),
    (nome: 'Índigo', cor: Color(0xFF5856D6)),
    (nome: 'Roxo', cor: Color(0xFFAF52DE)),
    (nome: 'Framboesa', cor: Color(0xFFE0356F)),
    (nome: 'Vermelho', cor: Color(0xFFE0362E)),
    (nome: 'Âmbar', cor: Color(0xFFC98A12)),
    (nome: 'Verde', cor: Color(0xFF30B356)),
    (nome: 'Turquesa', cor: Color(0xFF00A9A0)),
    (nome: 'Grafite', cor: Color(0xFF6E6E73)),
  ];

  static ThemeData light(
    Color? brand, {
    Color? secundaria,
    Color? fundo,
    Color? texto,
    String? fontFamily,
  }) => _base(
    Brightness.light,
    brand ?? seed,
    secundaria: secundaria,
    fundo: fundo,
    texto: texto,
    fontFamily: fontFamily,
  );

  static ThemeData dark(
    Color? brand, {
    Color? secundaria,
    Color? fundo,
    Color? texto,
    String? fontFamily,
  }) => _base(
    Brightness.dark,
    brand ?? seed,
    secundaria: secundaria,
    fundo: fundo,
    texto: texto,
    fontFamily: fontFamily,
  );

  /// Interpreta uma cor hex (`#RRGGBB` ou `RRGGBB`); `null` se inválida.
  static Color? parseHex(String value) {
    var v = value.trim().replaceFirst('#', '');
    if (v.length == 6) v = 'FF$v';
    if (v.length != 8) return null;
    final n = int.tryParse(v, radix: 16);
    return n == null ? null : Color(n);
  }

  /// `#RRGGBB` de uma cor (para gravar em `empresas.cor_marca`).
  static String toHex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static ThemeData _base(
    Brightness brightness,
    Color seedColor, {
    Color? secundaria,
    Color? fundo,
    Color? texto,
    String? fontFamily,
  }) {
    final isDark = brightness == Brightness.dark;
    var scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    // Distribuição de cores avançada (Configurações → Aparência): a cor de
    // marca continua a gerar a paleta base (M3 `fromSeed`, garante contraste),
    // mas secundária/texto podem ser trocadas independentemente por cima.
    if (secundaria != null) {
      scheme = scheme.copyWith(
        secondary: secundaria,
        secondaryContainer: Color.alphaBlend(
          secundaria.withValues(alpha: isDark ? 0.32 : 0.16),
          isDark ? Colors.black : Colors.white,
        ),
      );
    }
    if (texto != null) {
      scheme = scheme.copyWith(
        onSurface: texto,
        onSurfaceVariant: texto.withValues(alpha: 0.7),
      );
    }

    // Fundo suave, cartões mais claros por cima — a mesma leitura do
    // "grouped table view" do iOS (fundo cinza, cartões brancos).
    final background = fundo ?? scheme.surfaceContainerLow;
    final surfaceCard = isDark ? scheme.surfaceContainer : scheme.surface;

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    );
    final roundedSm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSm),
    );

    // Parte da tipografia M3 (tem todos os papéis preenchidos) e só ajusta
    // peso/espaçamento onde interessa — mais seguro do que construir de
    // raiz (evita ficar com estilos nulos nalgum canto da app).
    final baseText =
        (isDark
                ? Typography.material2021().white
                : Typography.material2021().black)
            .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final textTheme = baseText.copyWith(
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: baseText.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.35),
      bodySmall: baseText.bodySmall?.copyWith(
        height: 1.3,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: baseText.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      fontFamily: fontFamily,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: scheme.shadow.withValues(alpha: 0.15),
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceCard,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withValues(alpha: 0.10),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: rounded,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: roundedSm,
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
        thickness: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.5 : 0.6,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: roundedSm,
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 15.5,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: scheme.outlineVariant),
          shape: roundedSm,
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 15.5,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: roundedSm,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: const CircleBorder()),
      ),

      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        disabledColor: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
          visualDensity: VisualDensity.standard,
          // margens menores: os nomes cabem numa linha em telemóveis estreitos
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceCard,
        modalBackgroundColor: surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        modalElevation: 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.2),
        dragHandleColor: scheme.outlineVariant,
        dragHandleSize: const Size(36, 4),
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12.5),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.primary.withValues(alpha: 0.15),
      ),
    );
  }
}
