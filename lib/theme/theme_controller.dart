import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// 選択中のテーマ・ライト/ダークモード・曲名の表示方法を保持し、
/// 変更を永続化するコントローラ。
///
/// 既存の [AudioPlayerService] と同様にシングルトンとして扱い、
/// [MaterialApp] を [ListenableBuilder] で包んで購読する。
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _kThemeId = 'app_theme_id';
  static const String _kThemeMode = 'app_theme_mode';
  static const String _kCleanTitles = 'app_clean_titles';

  AppThemeId _themeId = AppThemeId.modern;
  ThemeMode _themeMode = ThemeMode.system;
  bool _cleanTitles = true;

  AppThemeId get themeId => _themeId;
  ThemeMode get themeMode => _themeMode;

  /// true なら【MV】や (Official Video) などを外して曲名を表示する。
  bool get cleanTitles => _cleanTitles;

  AppThemeData get currentTheme => AppThemes.byId(_themeId);

  /// 起動時に保存済みの設定を読み込む。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getString(_kThemeId);
    if (id != null) {
      _themeId = AppThemeId.values.firstWhere(
        (e) => e.name == id,
        orElse: () => AppThemeId.modern,
      );
    }

    final mode = prefs.getString(_kThemeMode);
    if (mode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == mode,
        orElse: () => ThemeMode.system,
      );
    }

    _cleanTitles = prefs.getBool(_kCleanTitles) ?? true;

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

  Future<void> setCleanTitles(bool value) async {
    if (_cleanTitles == value) return;
    _cleanTitles = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCleanTitles, value);
  }
}
