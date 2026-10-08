import 'package:flutter/material.dart';

/// アプリで使う書体のファミリー名(pubspec.yaml の fonts と対応)。
///
/// 見出し・曲名・ロゴは LINE Seed JP、本文は Murecho、数字は Geist Mono。
class AppFonts {
  AppFonts._();

  static const String display = 'LINESeedJP';
  static const String body = 'Murecho';
  static const String mono = 'GeistMono';

  /// 回数・時間などの数字。桁がずれないよう等幅数字にする。
  static TextStyle monoStyle({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: mono,
      // Geist Mono には日本語が無いので「回」「曲」などは本文の書体で描く
      fontFamilyFallback: const [body],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle displayStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: display,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

/// テーマごとの色・角丸・浮いている部品(下タブ・ミニプレイヤー等)の質感。
///
/// 画面の部品はどのテーマでも共通で、このパレットの値だけを差し替える。
/// モダン(ダーク)は Claude Design の 7a をそのまま写している。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.icon,
    required this.border,
    required this.accent,
    required this.accentLight,
    required this.accentDeep,
    required this.onAccent,
    required this.track,
    required this.barIdle,
    required this.artFallback,
    required this.playingOverlay,
    required this.glassBlur,
    required this.glassFill,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassShadow,
    required this.raisedShadows,
    required this.radiusCard,
    required this.radiusArtLarge,
    required this.radiusArtSmall,
    required this.radiusButton,
    required this.radiusChip,
    required this.radiusMini,
  });

  final Brightness brightness;

  /// 画面の地。
  final Color bg;

  /// 「続きから」や入力欄など、地から一段持ち上げた面。
  final Color surface;

  /// ダイアログ・ボトムシート・メニュー。
  final Color surfaceHigh;
  final Color text;
  final Color textMuted;
  final Color textFaint;

  /// ヘッダーのアイコンボタン。
  final Color icon;

  /// 枠線ボタンの線。
  final Color border;
  final Color accent;

  /// 再生ボタンのグラデーション(同じ色相の明→暗)。
  final Color accentLight;
  final Color accentDeep;
  final Color onAccent;

  /// 再生位置の輪・進捗線の未再生部分。
  final Color track;

  /// プレイヤーのバーの未再生部分。
  final Color barIdle;

  /// サムネイルが無いときの面。
  final Color artFallback;

  /// 再生中の曲のサムネイルに重ねる幕(イコライザを載せる)。
  final Color playingOverlay;

  /// true ならすりガラス(背景をぼかす)、false なら不透明の面と影で浮かせる。
  final bool glassBlur;
  final Color glassFill;
  final Color glassBorder;

  /// すりガラスの上端に引く細い明るい線。
  final Color glassHighlight;
  final Color glassShadow;

  /// ニューモフィズムの盛り上がり。他のテーマでは空。
  final List<BoxShadow> raisedShadows;

  final double radiusCard;
  final double radiusArtLarge;
  final double radiusArtSmall;
  final double radiusButton;
  final double radiusChip;
  final double radiusMini;

  bool get isDark => brightness == Brightness.dark;

  /// 再生ボタンの面。CSS の linear-gradient(160deg, ...) 相当。
  LinearGradient get playGradient => LinearGradient(
    begin: const Alignment(-0.36, -1),
    end: const Alignment(0.36, 1),
    colors: [accentLight, accentDeep],
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  // ---------------------------------------------------------------------------
  // モダン: 紫のアクセント。ダークは 7a の値そのまま。
  // ---------------------------------------------------------------------------

  static const AppPalette modernDark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF100F16),
    surface: Color(0xFF1A1922),
    surfaceHigh: Color(0xFF22212C),
    text: Color(0xFFF1EFF6),
    textMuted: Color(0xFFA8A5B6),
    textFaint: Color(0xFF75727F),
    icon: Color(0xFFCFCDD9),
    border: Color(0xFF3A3846),
    accent: Color(0xFFA78BFA),
    accentLight: Color(0xFFB9A2FB),
    accentDeep: Color(0xFF7C4DEB),
    onAccent: Color(0xFF160F2A),
    track: Color(0xFF2A2934),
    barIdle: Color(0xFF4A4658),
    artFallback: Color(0xFF24232E),
    playingOverlay: Color(0xA8100F16),
    glassBlur: true,
    glassFill: Color(0x6B2C2A3A),
    glassBorder: Color(0x24F1EFF6),
    glassHighlight: Color(0x29F1EFF6),
    glassShadow: Color(0x5908070E),
    raisedShadows: [],
    radiusCard: 20,
    radiusArtLarge: 14,
    radiusArtSmall: 10,
    radiusButton: 14,
    radiusChip: 10,
    radiusMini: 18,
  );

  static const AppPalette modernLight = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFFAFAFC),
    surface: Color(0xFFF0EEF6),
    surfaceHigh: Color(0xFFF7F6FB),
    text: Color(0xFF16151C),
    textMuted: Color(0xFF6A6878),
    textFaint: Color(0xFF9A98A8),
    icon: Color(0xFF3C3A48),
    border: Color(0xFFD9D6E3),
    accent: Color(0xFF7C3AED),
    accentLight: Color(0xFF9B6CF2),
    accentDeep: Color(0xFF6527D6),
    onAccent: Color(0xFFFFFFFF),
    track: Color(0xFFE4E0EE),
    barIdle: Color(0xFFD4D0E0),
    artFallback: Color(0xFFE8E5F0),
    playingOverlay: Color(0xB3FAFAFC),
    glassBlur: true,
    glassFill: Color(0x9EFFFFFF),
    glassBorder: Color(0x1416151C),
    glassHighlight: Color(0xCCFFFFFF),
    glassShadow: Color(0x1F3A3060),
    raisedShadows: [],
    radiusCard: 20,
    radiusArtLarge: 14,
    radiusArtSmall: 10,
    radiusButton: 14,
    radiusChip: 10,
    radiusMini: 18,
  );

  // ---------------------------------------------------------------------------
  // クラシック: ティールのアクセント。角を小さめにして落ち着かせる。
  // ---------------------------------------------------------------------------

  static const AppPalette classicDark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0E1213),
    surface: Color(0xFF171C1D),
    surfaceHigh: Color(0xFF1E2425),
    text: Color(0xFFE6EBEA),
    textMuted: Color(0xFF8A9594),
    textFaint: Color(0xFF5E6968),
    icon: Color(0xFFC9D2D0),
    border: Color(0xFF2E3637),
    accent: Color(0xFF3CB4A5),
    accentLight: Color(0xFF5CC7B9),
    accentDeep: Color(0xFF1E8C7F),
    onAccent: Color(0xFF04201C),
    track: Color(0xFF243032),
    barIdle: Color(0xFF35403F),
    artFallback: Color(0xFF1E2526),
    playingOverlay: Color(0xA80E1213),
    glassBlur: true,
    glassFill: Color(0x801E2627),
    glassBorder: Color(0x1FE6EBEA),
    glassHighlight: Color(0x1FE6EBEA),
    glassShadow: Color(0x59050808),
    raisedShadows: [],
    radiusCard: 12,
    radiusArtLarge: 8,
    radiusArtSmall: 6,
    radiusButton: 8,
    radiusChip: 8,
    radiusMini: 12,
  );

  static const AppPalette classicLight = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF5F6F5),
    surface: Color(0xFFE9EDEC),
    surfaceHigh: Color(0xFFF9FAF9),
    text: Color(0xFF141918),
    textMuted: Color(0xFF5E6968),
    textFaint: Color(0xFF8A9594),
    icon: Color(0xFF2E3736),
    border: Color(0xFFCDD5D3),
    accent: Color(0xFF00796B),
    accentLight: Color(0xFF26A69A),
    accentDeep: Color(0xFF00695C),
    onAccent: Color(0xFFFFFFFF),
    track: Color(0xFFDCE3E1),
    barIdle: Color(0xFFC5CFCC),
    artFallback: Color(0xFFE1E7E5),
    playingOverlay: Color(0xB3F5F6F5),
    glassBlur: true,
    glassFill: Color(0x99FFFFFF),
    glassBorder: Color(0x14141918),
    glassHighlight: Color(0xCCFFFFFF),
    glassShadow: Color(0x1F1E2B29),
    raisedShadows: [],
    radiusCard: 12,
    radiusArtLarge: 8,
    radiusArtSmall: 6,
    radiusButton: 8,
    radiusChip: 8,
    radiusMini: 12,
  );

  // ---------------------------------------------------------------------------
  // ニューモフィズム: 面と地を同じ色にし、影の盛り上がりで浮かせる。
  // すりガラスは使わない。
  // ---------------------------------------------------------------------------

  static const AppPalette neumorphismDark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF2C313A),
    surface: Color(0xFF2C313A),
    surfaceHigh: Color(0xFF333944),
    text: Color(0xFFE3E7EE),
    textMuted: Color(0xFF9AA3B0),
    textFaint: Color(0xFF6E7785),
    icon: Color(0xFFC9D0DA),
    border: Color(0xFF3B424E),
    accent: Color(0xFF7FB8C9),
    accentLight: Color(0xFF9CCAD8),
    accentDeep: Color(0xFF5E9BAE),
    onAccent: Color(0xFF13252B),
    track: Color(0xFF252A32),
    barIdle: Color(0xFF444C59),
    artFallback: Color(0xFF333944),
    playingOverlay: Color(0xB32C313A),
    glassBlur: false,
    glassFill: Color(0xFF2C313A),
    glassBorder: Color(0x00000000),
    glassHighlight: Color(0x00000000),
    glassShadow: Color(0x00000000),
    raisedShadows: [
      BoxShadow(color: Color(0xFF21252C), offset: Offset(5, 5), blurRadius: 10),
      BoxShadow(
        color: Color(0xFF373D48),
        offset: Offset(-4, -4),
        blurRadius: 9,
      ),
    ],
    radiusCard: 20,
    radiusArtLarge: 12,
    radiusArtSmall: 10,
    radiusButton: 14,
    radiusChip: 14,
    radiusMini: 20,
  );

  static const AppPalette neumorphismLight = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFE0E5EC),
    surface: Color(0xFFE0E5EC),
    surfaceHigh: Color(0xFFE8ECF1),
    text: Color(0xFF2D3440),
    textMuted: Color(0xFF626B78),
    textFaint: Color(0xFF8C95A2),
    icon: Color(0xFF3B4350),
    border: Color(0xFFC9D0DA),
    accent: Color(0xFF2F7F95),
    accentLight: Color(0xFF4A97AC),
    accentDeep: Color(0xFF24687B),
    onAccent: Color(0xFFFFFFFF),
    track: Color(0xFFCDD3DC),
    barIdle: Color(0xFFBEC6D1),
    artFallback: Color(0xFFD6DCE4),
    playingOverlay: Color(0xB3E0E5EC),
    glassBlur: false,
    glassFill: Color(0xFFE0E5EC),
    glassBorder: Color(0x00000000),
    glassHighlight: Color(0x00000000),
    glassShadow: Color(0x00000000),
    raisedShadows: [
      BoxShadow(color: Color(0xFFB8BEC7), offset: Offset(6, 6), blurRadius: 12),
      BoxShadow(
        color: Color(0xFFFFFFFF),
        offset: Offset(-6, -6),
        blurRadius: 12,
      ),
    ],
    radiusCard: 20,
    radiusArtLarge: 12,
    radiusArtSmall: 10,
    radiusButton: 14,
    radiusChip: 14,
    radiusMini: 20,
  );

  @override
  AppPalette copyWith() => this;

  /// テーマの切り替えは一瞬で済ませる(色の補間はしない)。
  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }
}
