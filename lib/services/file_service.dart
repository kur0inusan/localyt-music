import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p; // pubspec.yamlに追加必要
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/models/playlist.dart';

class PlaylistsManager {
  static const String storagePath =
      '/storage/emulated/0/Download/localyt_music';

  Future<List<Playlist>> getAllPlaylist() async {
    final Directory dir = Directory(storagePath);
    if (!await dir.exists()) return [];
    try {
      List<String> folderNames = dir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path)) // pathパッケージで安全にフォルダ名を抽出
          .toList();
      List<Playlist> playlists = [];
      for (String playlistName in folderNames) {
        final List<Song> songs = await PlaylistManager(
          playlistName,
        ).getPlaylistSongs(playlistName);
        playlists.add(Playlist(playlistName, songs.length));
      }
      return playlists;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to load playlists',
        error: e,
        stackTrace: stackTrace,
      );
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

  Future<void> deletePlaylistURL(String playlistName) async {
    if (playlistName.isEmpty) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(playlistName);
  }

  Future<bool> playlistExists(String playlistName) async {
    if (playlistName.isEmpty) return false;
    final Directory playlistDir = Directory(p.join(storagePath, playlistName));
    return playlistDir.exists();
  }

  Future<bool> playlistNameExists(String playlistName) async {
    if (playlistName.isEmpty) return false;
    final bool hasDirectory = await playlistExists(playlistName);
    final String savedUrl = await getPlayListURL(playlistName);
    return hasDirectory || savedUrl.isNotEmpty;
  }

  Future<void> renamePlaylist(String oldName, String newName) async {
    if (oldName.isEmpty || newName.isEmpty || oldName == newName) return;

    final Directory oldDir = Directory(p.join(storagePath, oldName));
    final Directory newDir = Directory(p.join(storagePath, newName));
    if (!await oldDir.exists()) {
      throw Exception('プレイリストフォルダが見つかりません');
    }
    if (await newDir.exists()) {
      throw Exception('同じ名前のプレイリストが既に存在します');
    }

    await oldDir.rename(newDir.path);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? url = prefs.getString(oldName);
    if (url != null) {
      await prefs.setString(newName, url);
      await prefs.remove(oldName);
    }
  }

  Future<void> deletePlaylist(String playlistName) async {
    if (playlistName.isEmpty) return;

    final Directory playlistDir = Directory(p.join(storagePath, playlistName));
    if (await playlistDir.exists()) {
      await playlistDir.delete(recursive: true);
    }
    await deletePlaylistURL(playlistName);
  }
}

class PlaylistManager {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.kuroinusan.localyt_music/youtubedl',
  );

  String playlistName;

  PlaylistManager(this.playlistName) {
    if (playlistName == '') {
      Exception('Playlist name is empty');
    }
  }

  Future<List<Song>> getPlaylistSongs(String playlistName) async {
    const String storagePath = PlaylistsManager.storagePath;
    final Directory dir = Directory(storagePath);
    if (!await dir.exists()) return [];
    try {
      final Directory playlistDir = Directory(
        p.join(storagePath, playlistName),
      );
      if (!await playlistDir.exists()) return [];
      final List<File> songFiles = await playlistDir
          .list(recursive: true)
          .where((entity) => entity is File)
          .cast<File>()
          .where((file) => p.extension(file.path).toLowerCase() == '.mp3')
          .toList();
      songFiles.sort((a, b) => a.path.compareTo(b.path));

      List<Song> songs = [];
      for (File songFile in songFiles) {
        final String songName = p.basenameWithoutExtension(songFile.path);
        Map<String, String>? metadata;
        try {
          metadata = await _methodChannel.invokeMapMethod<String, String>(
            'getAudioMetadata',
            {'path': songFile.path},
          );
        } catch (_) {
          metadata = null;
        }
        songs.add(
          Song(
            metadata?['title']?.isNotEmpty == true
                ? metadata!['title']!
                : songName,
            metadata?['album']?.isNotEmpty == true
                ? metadata!['album']!
                : playlistName,
            metadata?['artist'] ?? '',
            songFile.path,
            _findSidecarThumbnail(songFile),
          ),
        );
      }
      return songs;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to load playlist songs',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  String _findSidecarThumbnail(File songFile) {
    final String basePath = p.withoutExtension(songFile.path);
    for (final String extension in ['jpg', 'jpeg', 'png', 'webp']) {
      final File thumbnail = File('$basePath.$extension');
      if (thumbnail.existsSync()) {
        return thumbnail.path;
      }
    }
    return '';
  }
}
