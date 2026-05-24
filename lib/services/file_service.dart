import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;              // pubspec.yamlに追加必要

class PlaylistManager {
  Future<List<String>> getAllPlaylistName() async {
    const String storagePath = '/storage/emulated/0/Download/localyt_music';
    final Directory dir = Directory(storagePath);
    if (!await dir.exists()) return [];
    try {
      List<String> folderNames = dir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path)) // pathパッケージで安全にフォルダ名を抽出
          .toList();

      return folderNames;
    } catch (e) {
      print('error: $e');
      return [];
    }
  }

  Future<String> getPlayListURL(String playlistName) async {
    if (playlistName == '') return '';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(playlistName) ?? '';
  }

  Future<void> savePlaylistURL(String playlistName, String url) async {
    if (playlistName.isEmpty || url.isEmpty) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(playlistName, url);
  }
}