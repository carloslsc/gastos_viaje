import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppStyle { dark, midnight, slate, light }

// ── Theme extension for dynamic custom colors ─────────
class AppColors extends ThemeExtension<AppColors> {
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHigher;
  final Color border;
  final Color borderHover;
  final Color sidebar;
  final Color accent;
  final Color accentFill;

  const AppColors({
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHigher,
    required this.border,
    required this.borderHover,
    required this.sidebar,
    required this.accent,
    required this.accentFill,
  });

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceHigher,
    Color? border,
    Color? borderHover,
    Color? sidebar,
    Color? accent,
    Color? accentFill,
  }) => AppColors(
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    surfaceHigher: surfaceHigher ?? this.surfaceHigher,
    border: border ?? this.border,
    borderHover: borderHover ?? this.borderHover,
    sidebar: sidebar ?? this.sidebar,
    accent: accent ?? this.accent,
    accentFill: accentFill ?? this.accentFill,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceHigher: Color.lerp(surfaceHigher, other.surfaceHigher, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderHover: Color.lerp(borderHover, other.borderHover, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentFill: Color.lerp(accentFill, other.accentFill, t)!,
    );
  }
}

class AppTheme {
  // ── Stable semantic colors (never change with style) ──
  static const Color orange = Color(0xFFC8592A);
  static const Color orangeFill = Color(0x1AC8592A);
  static const Color green = Color(0xFF4CAF7D);
  static const Color greenFill = Color(0x1A4CAF7D);
  static const Color red = Color(0xFFE05C5C);
  static const Color redFill = Color(0x1AE05C5C);
  static const Color blue = Color(0xFF4FA3D4);
  static const Color blueFill = Color(0x1A4FA3D4);
  static const Color amber = Color(0xFFD4A017);
  static const Color amberFill = Color(0x1AD4A017);

  // ── Legacy static colors (kept for backward compat) ──
  static const Color background = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFF232323);
  static const Color surfaceHigh = Color(0xFF2D2D2D);
  static const Color surfaceHigher = Color(0xFF383838);
  static const Color border = Color(0xFF3A3A3A);
  static const Color borderHover = Color(0xFF505050);
  static const Color orangeLight = Color(0xFFE06030);
  static const Color orangeDark = Color(0xFF9C3E1A);
  static const Color textPrimary = Color(0xFFF5F3EF);
  static const Color textSecondary = Color(0xFF9E9488);
  static const Color textMuted = Color(0xFF6B6259);

  // Preferred order of palette indices when auto-assigning member colors.
  // 1=orange, 6=blue, 2=gold, then the rest.
  static const List<int> memberColorOrder = [1, 6, 2, 0, 3, 4, 5, 7, 8, 9];

  static const List<List<Color>> avatarPalette = [
    [Color(0xFF3A1A1A), Color(0xFFD45A5A)], // 0 Red
    [Color(0xFF3D1A0D), Color(0xFFC8592A)], // 1 Orange
    [Color(0xFF3D3200), Color(0xFFD4A017)], // 2 Gold
    [Color(0xFF2A3D1A), Color(0xFF7ED44F)], // 3 Lime
    [Color(0xFF1A3D2A), Color(0xFF4CAF7D)], // 4 Green
    [Color(0xFF1A3D3D), Color(0xFF4CBFBF)], // 5 Teal
    [Color(0xFF1A3A5C), Color(0xFF4FA3D4)], // 6 Blue
    [Color(0xFF2A1A3D), Color(0xFF9B82D4)], // 7 Purple
    [Color(0xFF2D1A3D), Color(0xFFB05AD4)], // 8 Violet
    [Color(0xFF3D1A2D), Color(0xFFD4679C)], // 9 Pink
  ];

  // ── Style background palette ───────────────────────
  // [bg, surface, surfHigh, surfHigher, border, sidebar]
  static List<Color> styleBg(AppStyle style) => switch (style) {
    AppStyle.dark => const [
      Color(0xFF1A1A1A), Color(0xFF232323), Color(0xFF2D2D2D),
      Color(0xFF383838), Color(0xFF3A3A3A), Color(0xFF141414),
    ],
    AppStyle.midnight => const [
      Color(0xFF0D0D0F), Color(0xFF151519), Color(0xFF1D1D24),
      Color(0xFF25252F), Color(0xFF2E2E3A), Color(0xFF090909),
    ],
    AppStyle.slate => const [
      Color(0xFF141820), Color(0xFF1C2130), Color(0xFF242C3E),
      Color(0xFF2C364E), Color(0xFF374256), Color(0xFF0F1319),
    ],
    AppStyle.light => const [
      Color(0xFFF5F4F0), Color(0xFFFFFFFF), Color(0xFFF0EDE8),
      Color(0xFFE8E4DE), Color(0xFFDDD8D0), Color(0xFFECE8E2),
    ],
  };

  // ── Style text palette ─────────────────────────────
  // [textPrimary, textSecondary, textMuted, borderHover]
  static List<Color> _styleText(AppStyle style) => switch (style) {
    AppStyle.light => const [
      Color(0xFF1A1816), Color(0xFF5A5550), Color(0xFF8A8278), Color(0xFFC0BAB0),
    ],
    _ => const [
      Color(0xFFF5F3EF), Color(0xFF9E9488), Color(0xFF6B6259), Color(0xFF505050),
    ],
  };

  static ThemeData get dark => build();

  static ThemeData build({
    Color accent = orange,
    AppStyle style = AppStyle.dark,
  }) {
    final bg = styleBg(style);
    final txt = _styleText(style);
    final bgColor = bg[0];
    final surfColor = bg[1];
    final surfHighColor = bg[2];
    final surfHigherColor = bg[3];
    final borderColor = bg[4];
    final sidebarColor = bg[5];
    final tPrimary = txt[0];
    final tSecondary = txt[1];
    final tMuted = txt[2];
    final bHover = txt[3];
    final accentFill = accent.withValues(alpha: 0.1);
    final isLight = style == AppStyle.light;

    return ThemeData(
      brightness: isLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      colorScheme: isLight
          ? ColorScheme.light(
              primary: accent,
              secondary: accent.withValues(alpha: 0.85),
              surface: surfColor,
              onPrimary: Colors.white,
              onSurface: tPrimary,
              surfaceContainerLowest: sidebarColor,
              surfaceContainerLow: surfHigherColor,
              outlineVariant: borderColor,
            )
          : ColorScheme.dark(
              primary: accent,
              secondary: accent.withValues(alpha: 0.85),
              surface: surfColor,
              onPrimary: Colors.white,
              onSurface: tPrimary,
              surfaceContainerLowest: sidebarColor,
              surfaceContainerLow: surfHigherColor,
              outlineVariant: borderColor,
            ),
      textTheme: GoogleFonts.interTextTheme(
        isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.inter(color: tPrimary, fontWeight: FontWeight.w300, fontSize: 32),
        headlineMedium: GoogleFonts.inter(color: tPrimary, fontWeight: FontWeight.w500, fontSize: 22),
        titleLarge: GoogleFonts.inter(color: tPrimary, fontWeight: FontWeight.w600, fontSize: 17),
        titleMedium: GoogleFonts.inter(color: tPrimary, fontWeight: FontWeight.w500, fontSize: 15),
        bodyLarge: GoogleFonts.inter(color: tPrimary, fontSize: 15),
        bodyMedium: GoogleFonts.inter(color: tSecondary, fontSize: 13),
        labelSmall: GoogleFonts.inter(color: tMuted, fontSize: 11, letterSpacing: 0.8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfColor,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(color: tPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: tPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfHigherColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: tMuted, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: tSecondary, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tSecondary,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: sidebarColor,
        selectedIconTheme: IconThemeData(color: accent),
        unselectedIconTheme: IconThemeData(color: tMuted),
        selectedLabelTextStyle: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(color: tMuted, fontSize: 12),
        indicatorColor: accentFill,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      extensions: [
        AppColors(
          textPrimary: tPrimary,
          textSecondary: tSecondary,
          textMuted: tMuted,
          background: bgColor,
          surface: surfColor,
          surfaceHigh: surfHighColor,
          surfaceHigher: surfHigherColor,
          border: borderColor,
          borderHover: bHover,
          sidebar: sidebarColor,
          accent: accent,
          accentFill: accentFill,
        ),
      ],
    );
  }
}
