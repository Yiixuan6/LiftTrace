import 'package:flutter/material.dart';
import '../domain/models.dart';

abstract final class ThemeTokens {
  static const spacingScale = [4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0];
  static const gap = 16.0, radius = 24.0, maxWidth = 1200.0;
  static const quick = Duration(milliseconds: 180);
  // Keep the reference's luminous CTA independent from the darker text/link
  // blue used for small labels. Large bold CTA text remains >= 3:1.
  static List<Color> homeActionColors(ThemeData theme) =>
      theme.brightness == Brightness.light &&
          theme.colorScheme.primary == seeds[BrandTheme.blue]
      ? const [Color(0xff2098f5), Color(0xff0084ff)]
      : [
          Color.lerp(theme.colorScheme.primary, Colors.white, .08)!,
          theme.colorScheme.primary,
        ];
  static const seeds = {
    BrandTheme.orange: Color(0xffbd4b18),
    BrandTheme.blue: Color(0xff0065cb),
    BrandTheme.sage: Color(0xff4e7054),
  };
  static const editorialSurface = Color(0xfffaf9f5);
  static const editorialInk = Color(0xff07353c);
  static const glassRim = [
    Color(0xff62f1e8),
    Color(0xffffd6ef),
    Color(0xffffffff),
    Color(0xffe6eef7),
    Color(0xffc9f2ee),
  ];
  static const glassLightTints = [
    Color(0x50e2f8f6),
    Color(0x48fff0fa),
    Color(0x60ffffff),
    Color(0x48e6eff1),
    Color(0x50f1fbf8),
  ];
}

@immutable
class GlassPalette extends ThemeExtension<GlassPalette> {
  const GlassPalette({
    required this.fill,
    required this.selection,
    required this.heroShade,
  });
  final Color fill, selection, heroShade;
  @override
  GlassPalette copyWith({Color? fill, Color? selection, Color? heroShade}) =>
      GlassPalette(
        fill: fill ?? this.fill,
        selection: selection ?? this.selection,
        heroShade: heroShade ?? this.heroShade,
      );
  @override
  GlassPalette lerp(covariant GlassPalette? other, double t) => other == null
      ? this
      : GlassPalette(
          fill: Color.lerp(fill, other.fill, t)!,
          selection: Color.lerp(selection, other.selection, t)!,
          heroShade: Color.lerp(heroShade, other.heroShade, t)!,
        );
}

@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.success,
    required this.warning,
    required this.chart,
  });
  final Color success, warning, chart;
  @override
  SemanticColors copyWith({Color? success, Color? warning, Color? chart}) =>
      SemanticColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        chart: chart ?? this.chart,
      );
  @override
  SemanticColors lerp(covariant SemanticColors? other, double t) =>
      other == null
      ? this
      : SemanticColors(
          success: Color.lerp(success, other.success, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
          chart: Color.lerp(chart, other.chart, t)!,
        );
}

abstract final class AppTheme {
  /// Content-only styling. Home and the navigation surface retain their theme.
  static ThemeData editorial(ThemeData base) {
    final c = base.colorScheme;
    final controls = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 56)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      textStyle: WidgetStatePropertyAll(
        base.textTheme.labelLarge?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
    return base.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: (base.filledButtonTheme.style ?? const ButtonStyle()).merge(
          controls,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).merge(
          controls,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: (base.textButtonTheme.style ?? const ButtonStyle()).merge(
          controls,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        margin: EdgeInsets.zero,
        color: Color.alphaBlend(c.primary.withValues(alpha: .025), c.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.outlineVariant.withValues(alpha: .65)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        iconColor: c.primary,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          color: c.onSurface,
        ),
        subtitleTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: c.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: c.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      dividerTheme: DividerThemeData(color: c.outlineVariant, space: 1),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(c.surfaceContainerLow),
        side: WidgetStatePropertyAll(BorderSide(color: c.outlineVariant)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: c.surface,
        selectedColor: c.primary.withValues(alpha: .10),
        checkmarkColor: c.primary,
        side: BorderSide(color: c.outlineVariant),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? c.primary.withValues(alpha: .10)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? c.primary : c.onSurface,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: c.outlineVariant)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        showDragHandle: true,
      ),
    );
  }

  static ThemeData build(BrandTheme brand, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    var colors = ColorScheme.fromSeed(
      seedColor: ThemeTokens.seeds[brand]!,
      brightness: brightness,
    );
    if (!dark) {
      colors = colors.copyWith(
        surface: ThemeTokens.editorialSurface,
        onSurface: ThemeTokens.editorialInk,
        onSurfaceVariant: const Color(0xff506670),
        surfaceContainerLow: const Color(0xfff0f2ee),
        surfaceContainerHighest: const Color(0xffe9eeed),
        outlineVariant: const Color(0xffdae3e3),
      );
      if (brand == BrandTheme.blue) {
        colors = colors.copyWith(
          primary: ThemeTokens.seeds[brand],
          onPrimary: Colors.white,
        );
      }
    }
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    return base.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      visualDensity: VisualDensity.standard,
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        scrolledUnderElevation: 0,
        titleTextStyle: base.textTheme.headlineSmall?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        showDragHandle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeTokens.radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      extensions: [
        GlassPalette(
          fill: dark ? const Color(0x9827343b) : const Color(0x60ffffff),
          selection: dark ? const Color(0xff364a55) : const Color(0xffe8edee),
          heroShade: dark
              ? colors.surface.withValues(alpha: .80)
              : colors.surface.withValues(alpha: 0),
        ),
        SemanticColors(
          success: colors.tertiary,
          warning: colors.error,
          chart: colors.secondary,
        ),
      ],
    );
  }
}
