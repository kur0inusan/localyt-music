import 'dart:convert';
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
  static const String playlistUrlFileName = 'playlist_url.txt';
  static const String playlistOrderFileName = '.playlist_order.json';

  File _playlistUrlFile(String playlistName) =>
      File(p.join(storagePath, playlistName, playlistUrlFileName));

  File get _playlistOrderFile =>
      File(p.join(storagePath, playlistOrderFileName));

  Future<List<String>> _readPlaylistOrder() async {
    try {
      if (!await _playlistOrderFile.exists()) return [];
      final Object? decoded = jsonDecode(
        await _playlistOrderFile.readAsString(),
      );
      if (decoded is! List) return [];
      return decoded.whereType<String>().toList();
    } catch (e, stackTrace) {
      developer.log(
        'Failed to read playlist order',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<List<Playlist>> getAllPlaylist() async {
    final Directory dir = Directory(storagePath);
    if (!await dir.exists()) return [];
    try {
      List<String> folderNames = dir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path)) // pathパッケージで安全にフォルダ名を抽出
          .toList();
      // 順序ファイルがまだない既存ユーザーにも毎回同じ初期順序を表示する。
      folderNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final List<String> savedOrder = await _readPlaylistOrder();
      final Set<String> remainingNames = folderNames.toSet();
      final List<String> orderedFolderNames = [];
      for (final String playlistName in savedOrder) {
        if (remainingNames.remove(playlistName)) {
          orderedFolderNames.add(playlistName);
        }
      }
      // 新規作成や外部から追加されたフォルダは、保存済み順序の末尾へ加える。
      orderedFolderNames.addAll(folderNames.where(remainingNames.contains));

      List<Playlist> playlists = [];
      for (String playlistName in orderedFolderNames) {
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

  Future<void> savePlaylistOrder(List<String> playlistNames) async {
    final Directory dir = Directory(storagePath);
    if (!await dir.exists()) {
      throw const FileSystemException('プレイリストフォルダが見つかりません');
    }

    final List<String> existingNames = await dir
        .list()
        .where((entity) => entity is Directory)
        .map((entity) => p.basename(entity.path))
        .toList();
    existingNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final Set<String> remainingNames = existingNames.toSet();
    final List<String> normalizedOrder = [];
    for (final String playlistName in playlistNames) {
      if (remainingNames.remove(playlistName)) {
        normalizedOrder.add(playlistName);
      }
    }
    // 保存処理中に外部で追加されたフォルダも失わず末尾へ残す。
    normalizedOrder.addAll(existingNames.where(remainingNames.contains));

    await _playlistOrderFile.writeAsString(
      jsonEncode(normalizedOrder),
      flush: true,
    );
  }

  Future<void> _replacePlaylistNameInOrder(
    String oldName,
    String newName,
  ) async {
    final List<String> savedOrder = await _readPlaylistOrder();
    final int index = savedOrder.indexOf(oldName);
    if (index < 0) return;
    savedOrder[index] = newName;
    await savePlaylistOrder(savedOrder);
  }

  Future<void> _removePlaylistFromOrder(String playlistName) async {
    final List<String> savedOrder = await _readPlaylistOrder();
    if (!savedOrder.remove(playlistName)) return;
    await savePlaylistOrder(savedOrder);
  }

  Future<String> getPlayListURL(String playlistName) async {
    if (playlistName.isEmpty) return '';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final File urlFile = _playlistUrlFile(playlistName);

    // 外部ストレージ上のファイルを正とする。アプリ更新や再インストールで
    // SharedPreferences が失われても、プレイリストフォルダから復元できる。
    try {
      if (await urlFile.exists()) {
        final String fileUrl = (await urlFile.readAsString()).trim();
        if (fileUrl.isNotEmpty) {
          if (prefs.getString(playlistName) != fileUrl) {
            await prefs.setString(playlistName, fileUrl);
          }
          return fileUrl;
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to read playlist URL file',
        error: e,
        stackTrace: stackTrace,
      );
    }

    final String savedUrl = prefs.getString(playlistName) ?? '';
    if (savedUrl.isNotEmpty) {
      // 旧バージョンで作られたプレイリストは、従来の保存値から一度だけ
      // URLファイルを作って新しい保存方式へ移行する。
      try {
        final Directory playlistDir = urlFile.parent;
        if (await playlistDir.exists()) {
          await urlFile.writeAsString('$savedUrl\n', flush: true);
        }
      } catch (e, stackTrace) {
        developer.log(
          'Failed to migrate playlist URL to file',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    return savedUrl;
  }

  Future<void> savePlaylistURL(String playlistName, String url) async {
    if (playlistName.isEmpty || url.isEmpty) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(playlistName, url);

    // 既にフォルダがある場合はファイル側も更新する。新規追加では
    // DownloadService がフォルダ作成直後に同じファイルを書き込む。
    final File urlFile = _playlistUrlFile(playlistName);
    if (await urlFile.parent.exists()) {
      await urlFile.writeAsString('${url.trim()}\n', flush: true);
    }
  }

  Future<void> deletePlaylistURL(String playlistName) async {
    if (playlistName.isEmpty) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(playlistName);
    final File urlFile = _playlistUrlFile(playlistName);
    if (await urlFile.exists()) {
      await urlFile.delete();
    }
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

    try {
      await _replacePlaylistNameInOrder(oldName, newName);
    } catch (e, stackTrace) {
      // リネーム自体は完了しているため失敗扱いにはせず、次回一覧では
      // 保存順序にない新しい名前として末尾へ表示する。
      developer.log(
        'Failed to update playlist order after rename',
        error: e,
        stackTrace: stackTrace,
      );
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
      if (await playlistDir.exists() && playlistDir.listSync().isNotEmpty) {
        throw const FileSystemException('一部のファイルを削除できませんでした');
      }
    }
    await deletePlaylistURL(playlistName);
    try {
      await _removePlaylistFromOrder(playlistName);
    } catch (e, stackTrace) {
      // 残った名前は一覧読み込み時に存在確認で除外される。
      developer.log(
        'Failed to update playlist order after deletion',
        error: e,
        stackTrace: stackTrace,
      );
    }
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
        metadataList =
            result
                ?.map(
                  (e) => e == null ? null : Map<String, String>.from(e as Map),
                )
                .toList() ??
            List<Map<String, String>?>.filled(paths.length, null);
      } catch (_) {
        metadataList = List<Map<String, String>?>.filled(paths.length, null);
      }

      // 追加日順の並べ替え用。1曲ずつ待つと曲数分直列になるため並列に取得する。
      final List<DateTime?> addedAtList = await Future.wait(
        songFiles.map((file) async {
          try {
            return await file.lastModified();
          } on FileSystemException {
            return null;
          }
        }),
      );

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
            addedAtList[i],
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
