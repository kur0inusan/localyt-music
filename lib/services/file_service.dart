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
        // 曲数の表示だけならメタデータ(ネイティブ呼び出し)は不要なので、
        // ファイル数を数えるだけの軽量な方法を使う。大量の曲を持つ
        // プレイリストがあると、一覧表示のたびに曲数分のMethodChannel
        // 呼び出しが発生してUIがフリーズする原因になっていた。
        final int count = await PlaylistManager(playlistName).countSongs();
        playlists.add(Playlist(playlistName, count));
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
      // Android 11+ のスコープドストレージ(FUSE)では、ディレクトリ内の
      // メディアファイルを全て削除すると空ディレクトリが OS 側で自動的に
      // 消えることがある。その状態で Directory.delete(recursive:true) を
      // 呼ぶと "No such file or directory" (path not found) で失敗するため、
      // ファイルを個別に削除し、ディレクトリの未検出エラーは無視する。
      try {
        final List<FileSystemEntity> entries = playlistDir.listSync(
          recursive: true,
        );
        // 深い階層のものから削除できるようにパスの長い順に並べる
        entries.sort((a, b) => b.path.length.compareTo(a.path.length));
        for (final FileSystemEntity entity in entries) {
          try {
            await entity.delete(recursive: true);
          } on FileSystemException {
            // 既に消えている等の未検出エラーは無視する
          }
        }
      } on FileSystemException {
        // 一覧取得自体の失敗は下の最終削除・検証に委ねる
      }

      // 残ったディレクトリ本体を削除。既に FUSE が消していれば未検出エラーに
      // なるので無視する。
      try {
        if (await playlistDir.exists()) {
          await playlistDir.delete(recursive: true);
        }
      } on FileSystemException {
        // 既に存在しない場合は削除成功とみなす
      }

      // 本当に消えたか検証する。ファイルが残っている場合は権限などによる
      // 実際の失敗なので、呼び出し元にエラーを伝える。
      if (await playlistDir.exists() &&
          playlistDir.listSync().isNotEmpty) {
        throw const FileSystemException(
          '一部のファイルを削除できませんでした',
        );
      }
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

  /// メタデータを取得せずに曲数だけを数える。プレイリスト一覧表示など
  /// 曲数さえ分かればよい場面で使う軽量版(ネイティブ呼び出しなし)。
  Future<int> countSongs() async {
    final Directory playlistDir = Directory(
      p.join(PlaylistsManager.storagePath, playlistName),
    );
    if (!await playlistDir.exists()) return 0;
    try {
      return await playlistDir
          .list(recursive: true)
          .where(
            (entity) =>
                entity is File &&
                p.extension(entity.path).toLowerCase() == '.mp3',
          )
          .length;
    } catch (_) {
      return 0;
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

      // 曲ごとに1回ずつMethodChannelを呼ぶと、曲数が多いプレイリストで
      // ネイティブ側とのIPCラウンドトリップが直列に積み重なり著しく遅くなる。
      // 全ファイルパスをまとめて1回のバッチ呼び出しで処理する。
      final List<String> paths = songFiles.map((f) => f.path).toList();
      List<Map<String, String>?> metadataList;
      try {
        final List<Object?>? result = await _methodChannel
            .invokeMethod<List<Object?>>('getAudioMetadataBatch', {
              'paths': paths,
            });
        metadataList = result
                ?.map(
                  (e) => e == null
                      ? null
                      : Map<String, String>.from(e as Map),
                )
                .toList() ??
            List<Map<String, String>?>.filled(paths.length, null);
      } catch (_) {
        metadataList = List<Map<String, String>?>.filled(paths.length, null);
      }

      List<Song> songs = [];
      for (int i = 0; i < songFiles.length; i++) {
        final File songFile = songFiles[i];
        final Map<String, String>? metadata = metadataList[i];
        final String songName = p.basenameWithoutExtension(songFile.path);
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
