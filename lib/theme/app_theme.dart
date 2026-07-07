import 'package:flutter/material.dart';

/// アプリで選択できるテーマの種類。
enum AppThemeId { classic, neumorphism, modern }

/// 1つのテーマが持つ情報(表示名・説明・ライト/ダークの [ThemeData]・プレビュー色)。
class AppThemeData {
  const AppThemeData({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.light,
    required this.dark,
    required this.previewBackground,
    required this.previewPrimary,
    required this.previewSurface,
  });

  final AppThemeId id;
  final String label;
  final String description;
  final IconData icon;
  final ThemeData light;
  final ThemeData dark;

  /// 設定画面でプレビュー表示に使う代表色。
  final Color previewBackground;
  final Color previewPrimary;
  final Color previewSurface;
}

/// 全テーマの定義と取得用のヘルパ。
class AppThemes {
  AppThemes._();

  static final List<AppThemeData> all = [
    _classic(),
    _neumorphism(),
    _modern(),
  ];

  static AppThemeData byId(AppThemeId id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);

  // ---------------------------------------------------------------------------
  // 共通ビルダー
  // ---------------------------------------------------------------------------

  /// [ColorScheme] と形状・ボタン形状などからアプリ全体の [ThemeData] を組み立てる。
  static ThemeData _build({
    required ColorScheme scheme,
    required double radius,
    required bool pillButtons,
    Color? scaffoldBackground,
    double cardElevation = 1,
    double appBarElevation = 0,
    Color? cardShadowColor,
    FontWeight titleWeight = FontWeight.w600,
  }) {
    final OutlinedBorder buttonShape = pillButtons
        ? const StadiumBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final RoundedRectangleBorder cardShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scaffoldBackground ?? scheme.surface,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground ?? scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: appBarElevation,
        scrolledUnderElevation: appBarElevation,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: titleWeight,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: cardElevation,
        color: scheme.surfaceContainerHigh,
        shadowColor: cardShadowColor ?? scheme.shadow,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: ListTileThemeData(
        shape: cardShape,
        iconColor: scheme.onSurfaceVariant,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: buttonShape),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: buttonShape),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: buttonShape),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // クラシック (これまでの Material3 teal)
  // ---------------------------------------------------------------------------

  static AppThemeData _classic() {
    const seed = Color(0xFF00897B);
    final lightScheme = ColorScheme.fromSeed(seedColor: seed);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return AppThemeData(
      id: AppThemeId.classic,
      label: 'クラシック',
      description: 'これまでの Material 3 / ティールカラー',
      icon: Icons.water_drop_outlined,
      light: ThemeData(colorScheme: lightScheme, useMaterial3: true),
      dark: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      previewBackground: lightScheme.surface,
      previewPrimary: lightScheme.primary,
      previewSurface: lightScheme.surfaceContainerHigh,
    );
  }

  // ---------------------------------------------------------------------------
  // ニューモフィズム (やわらかいモノトーン)
  // ---------------------------------------------------------------------------

  static AppThemeData _neumorphism() {
    // ライト: 定番のグレーブルー地。要素と背景の色差を小さくして陰影で表現する。
    const lightBg = Color(0xFFE0E5EC);
    final lightScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B7089),
          brightness: Brightness.light,
        ).copyWith(
          surface: lightBg,
          surfaceContainerLowest: const Color(0xFFEAEEF4),
          surfaceContainerLow: const Color(0xFFE4E9F0),
          surfaceContainer: lightBg,
          surfaceContainerHigh: const Color(0xFFDAE0E8),
          surfaceContainerHighest: const Color(0xFFD3D9E1),
          onSurface: const Color(0xFF44505F),
          onSurfaceVariant: const Color(0xFF6B7787),
          shadow: const Color(0xFFA3B1C6),
        );

    const darkBg = Color(0xFF2C313A);
    final darkScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF8FA3BC),
          brightness: Brightness.dark,
        ).copyWith(
          surface: darkBg,
          surfaceContainerLowest: const Color(0xFF252A32),
          surfaceContainerLow: const Color(0xFF2C313A),
          surfaceContainer: darkBg,
          surfaceContainerHigh: const Color(0xFF333944),
          surfaceContainerHighest: const Color(0xFF3B424E),
          onSurface: const Color(0xFFD3D9E1),
          shadow: Colors.black,
        );

    return AppThemeData(
      id: AppThemeId.neumorphism,
      label: 'ニューモフィズム',
      description: 'やわらかい陰影のモノトーンデザイン',
      icon: Icons.blur_on,
      light: _build(
        scheme: lightScheme,
        radius: 20,
        pillButtons: false,
        scaffoldBackground: lightBg,
        cardElevation: 6,
        cardShadowColor: const Color(0xFFA3B1C6),
        titleWeight: FontWeight.w600,
      ),
      dark: _build(
        scheme: darkScheme,
        radius: 20,
        pillButtons: false,
        scaffoldBackground: darkBg,
        cardElevation: 6,
        cardShadowColor: Colors.black,
        titleWeight: FontWeight.w600,
      ),
      previewBackground: lightBg,
      previewPrimary: const Color(0xFF5B7089),
      previewSurface: const Color(0xFFDAE0E8),
    );
  }

  // ---------------------------------------------------------------------------
  // モダン (高コントラスト・ビビッドアクセント・丸みのあるピル)
  // ---------------------------------------------------------------------------

  static AppThemeData _modern() {
    const accent = Color(0xFF8B5CF6); // violet
    const accent2 = Color(0xFFEC4899); // pink

    final darkScheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: accent,
          secondary: accent2,
          surface: const Color(0xFF0F0F14),
          surfaceContainerLowest: const Color(0xFF09090C),
          surfaceContainerLow: const Color(0xFF141419),
          surfaceContainer: const Color(0xFF1A1A21),
          surfaceContainerHigh: const Color(0xFF22222B),
          surfaceContainerHighest: const Color(0xFF2B2B36),
          onSurface: const Color(0xFFF2F2F7),
        );

    final lightScheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
        ).copyWith(
          primary: accent,
          secondary: accent2,
          surface: const Color(0xFFFAFAFE),
          surfaceContainerHigh: Colors.white,
        );

    return AppThemeData(
      id: AppThemeId.modern,
      label: 'モダン',
      description: '高コントラスト・ビビッドな今風デザイン',
      icon: Icons.auto_awesome,
      light: _build(
        scheme: lightScheme,
        radius: 18,
        pillButtons: true,
        cardElevation: 2,
        titleWeight: FontWeight.w700,
      ),
      dark: _build(
        scheme: darkScheme,
        radius: 18,
        pillButtons: true,
        scaffoldBackground: const Color(0xFF0F0F14),
        cardElevation: 0,
        titleWeight: FontWeight.w700,
      ),
      previewBackground: const Color(0xFF0F0F14),
      previewPrimary: accent,
      previewSurface: const Color(0xFF22222B),
    );
  }
}
