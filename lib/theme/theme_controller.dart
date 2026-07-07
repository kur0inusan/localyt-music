import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// 選択中のテーマとライト/ダークモードを保持し、変更を永続化するコントローラ。
///
/// 既存の [AudioPlayerService] と同様にシングルトンとして扱い、
/// [MaterialApp] を [ListenableBuilder] で包んで購読する。
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _kThemeId = 'app_theme_id';
  static const String _kThemeMode = 'app_theme_mode';

  AppThemeId _themeId = AppThemeId.classic;
  ThemeMode _themeMode = ThemeMode.system;

  AppThemeId get themeId => _themeId;
  ThemeMode get themeMode => _themeMode;

  AppThemeData get currentTheme => AppThemes.byId(_themeId);

  /// 起動時に保存済みの設定を読み込む。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getString(_kThemeId);
    if (id != null) {
      _themeId = AppThemeId.values.firstWhere(
        (e) => e.name == id,
        orElse: () => AppThemeId.classic,
      );
    }

    final mode = prefs.getString(_kThemeMode);
    if (mode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == mode,
        orElse: () => ThemeMode.system,
      );
    }

    notifyListeners();
  }

  Future<void> setThemeId(AppThemeId id) async {
    if (_themeId == id) return;
    _themeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeId, id.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }
}
