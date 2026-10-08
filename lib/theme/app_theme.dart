import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'app_palette.dart';

/// アプリで選択できるテーマの種類。
enum AppThemeId { classic, neumorphism, modern }

/// 1つのテーマが持つ情報(表示名・説明・ライト/ダークのパレット)。
///
/// 画面の部品はどのテーマでも共通で、変わるのは [AppPalette] の色・角丸・
/// 浮いている部品の質感だけ。
class AppThemeData {
  AppThemeData({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.lightPalette,
    required this.darkPalette,
  }) : light = buildAppTheme(lightPalette),
       dark = buildAppTheme(darkPalette);

  final AppThemeId id;
  final String label;
  final String description;
  final IconData icon;
  final AppPalette lightPalette;
  final AppPalette darkPalette;
  final ThemeData light;
  final ThemeData dark;

  AppPalette paletteFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkPalette : lightPalette;
}

/// 全テーマの定義と取得用のヘルパ。
class AppThemes {
  AppThemes._();

  static final List<AppThemeData> all = [
    AppThemeData(
      id: AppThemeId.classic,
      label: 'クラシック',
      description: 'ティールのアクセントと控えめな角丸',
      icon: Symbols.water_drop_rounded,
      lightPalette: AppPalette.classicLight,
      darkPalette: AppPalette.classicDark,
    ),
    AppThemeData(
      id: AppThemeId.neumorphism,
      label: 'ニューモフィズム',
      description: 'やわらかい陰影で浮かせるモノトーン',
      icon: Symbols.blur_on_rounded,
      lightPalette: AppPalette.neumorphismLight,
      darkPalette: AppPalette.neumorphismDark,
    ),
    AppThemeData(
      id: AppThemeId.modern,
      label: 'モダン',
      description: '紫のアクセントとすりガラス',
      icon: Symbols.auto_awesome_rounded,
      lightPalette: AppPalette.modernLight,
      darkPalette: AppPalette.modernDark,
    ),
  ];

  static AppThemeData byId(AppThemeId id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);
}

/// パレットからアプリ全体の [ThemeData] を組み立てる。
///
/// 独自に組んだ部品はパレットを直接参照し、ダイアログ・入力欄・スイッチ等の
/// Material 部品はここで同じ色・書体・角丸にそろえる。
ThemeData buildAppTheme(AppPalette p) {
  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: p.brightness,
      ).copyWith(
        primary: p.accent,
        onPrimary: p.onAccent,
        secondary: p.accent,
        onSecondary: p.onAccent,
        surface: p.bg,
        onSurface: p.text,
        onSurfaceVariant: p.textMuted,
        surfaceContainerLowest: p.bg,
        surfaceContainerLow: p.surface,
        surfaceContainer: p.surface,
        surfaceContainerHigh: p.surfaceHigh,
        surfaceContainerHighest: p.surfaceHigh,
        outline: p.border,
        outlineVariant: p.border,
        shadow: p.glassShadow,
      );

  final ThemeData base = ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
    fontFamily: AppFonts.body,
    scaffoldBackgroundColor: p.bg,
  );

  final TextTheme textTheme = base.textTheme
      .apply(bodyColor: p.text, displayColor: p.text)
      .copyWith(
        headlineMedium: AppFonts.displayStyle(fontSize: 26, color: p.text),
        headlineSmall: AppFonts.displayStyle(fontSize: 22, color: p.text),
        titleLarge: AppFonts.displayStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
      );

  final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(p.radiusButton),
  );
  final OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(p.radiusButton),
    borderSide: BorderSide.none,
  );

  return base.copyWith(
    textTheme: textTheme,
    extensions: [p],
    iconTheme: IconThemeData(color: p.icon, weight: 300, fill: 0, size: 24),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: _QuickPageTransitionsBuilder()},
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) =>
          const Icon(Symbols.arrow_back_rounded),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: p.icon, weight: 300, fill: 0),
      systemOverlayStyle: systemOverlayFor(p),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(p.radiusCard),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.textMuted,
      textColor: p.text,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 15,
        color: p.text,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 12,
        height: 1.5,
        color: p.textMuted,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: p.border.withValues(alpha: 0.6),
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.track,
        disabledForegroundColor: p.textFaint,
        minimumSize: const Size(64, 52),
        shape: buttonShape,
        textStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        side: BorderSide(color: p.border),
        minimumSize: const Size(64, 52),
        shape: buttonShape,
        textStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        shape: buttonShape,
        textStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.icon),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      labelStyle: TextStyle(color: p.textMuted),
      hintStyle: TextStyle(color: p.textFaint),
      prefixIconColor: p.textMuted,
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: p.accent, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 14,
        height: 1.6,
        color: p.textMuted,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.border,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 14,
        color: p.text,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.surfaceHigh,
      contentTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 13,
        color: p.text,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? p.onAccent : p.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.accent : p.track,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        foregroundColor: p.textMuted,
        selectedForegroundColor: p.onAccent,
        selectedBackgroundColor: p.accent,
        side: BorderSide(color: p.border),
        textStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 13),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.track,
      circularTrackColor: p.track,
      linearMinHeight: 6,
      borderRadius: BorderRadius.circular(3),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.track,
      thumbColor: p.accent,
    ),
  );
}

/// ステータスバー・ナビゲーションバーのアイコン色を地の明るさに合わせる。
SystemUiOverlayStyle systemOverlayFor(AppPalette p) {
  final SystemUiOverlayStyle base = p.isDark
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;
  return base.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}

/// 画面の切り替え。新しい画面が右から滑り込み、前の画面は少し左へずれて暗くなる。
///
/// Android 標準(FadeForwards)は両方の画面を半透明にして重ねるため、毎フレーム
/// 画面2枚分の重ね描きが要り、すりガラスと合わせると出だしが引っかかる。
/// ここでは不透明のまま動かすだけにして描く量を抑え、動き出しも速くする
/// (標準の曲線は出だしがゆっくりで、押してから反応が遅く見える)。
class _QuickPageTransitionsBuilder extends PageTransitionsBuilder {
  const _QuickPageTransitionsBuilder();

  static const Offset _behindOffset = Offset(-0.3, 0);
  static const double _behindDim = 0.35;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  DelegatedTransitionBuilder? get delegatedTransition => null;

  /// 進むときは速く動き出して止まり、戻るときも速く動き出す。
  static Curve _curveFor(Animation<double> animation) =>
      animation.status == AnimationStatus.reverse
      ? Curves.easeInCubic
      : Curves.easeOutCubic;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // ルートのアニメーションが進むたびに呼ばれるので、値から直接組み立てる
    final double shown = animation.isCompleted
        ? 1
        : _curveFor(animation).transform(animation.value);
    final double covered = secondaryAnimation.isDismissed
        ? 0
        : _curveFor(secondaryAnimation).transform(secondaryAnimation.value);
    return FractionalTranslation(
      translation: Offset(1 - shown, 0) + _behindOffset * covered,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: _behindDim * covered),
        ),
        child: child,
      ),
    );
  }
}
