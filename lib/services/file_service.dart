import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p; // pubspec.yamlに追加必要
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/models/playlist.dart';
import 'package:localyt_music/services/song_metadata_cache.dart';

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

  /// プレイリスト名を、保存した並び順で返す。
  Future<List<String>> getPlaylistNames() async {
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
      return orderedFolderNames;
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
    PlaylistManager.forgetCachedSongs(oldName);

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
    PlaylistManager.forgetCachedSongs(playlistName);
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

  /// 最後に読んだプレイリストごとの曲。開き直したときにすぐ表示するため。
  static final Map<String, List<Song>> _songsCache = {};

  /// [playlistName] の曲を前に読んでいれば返す。
  static List<Song>? cachedSongs(String playlistName) =>
      _songsCache[playlistName];

  static void forgetCachedSongs(String playlistName) =>
      _songsCache.remove(playlistName);

  String playlistName;

  PlaylistManager(this.playlistName) {
    if (playlistName == '') {
      Exception('Playlist name is empty');
    }
  }

  /// メタデータを読まずにファイル名から曲一覧を作る。ホーム画面のおすすめなど、
  /// 全プレイリストを横断する場面で使う軽量版(ネイティブ呼び出しなし)。
  /// ファイル名は yt-dlp の出力テンプレートで曲名になっている。
  Future<List<Song>> getSongsWithoutMetadata() async {
    final Directory playlistDir = Directory(
      p.join(PlaylistsManager.storagePath, playlistName),
    );
    if (!await playlistDir.exists()) return [];
    try {
      final _PlaylistFiles files = await _listFiles(playlistDir);
      return [
        for (final File songFile in files.songs)
          Song(
            p.basenameWithoutExtension(songFile.path),
            playlistName,
            '',
            songFile.path,
            files.sidecarThumbnailOf(songFile),
          ),
      ];
    } catch (e, stackTrace) {
      developer.log(
        'Failed to list playlist songs',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
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
      final _PlaylistFiles files = await _listFiles(playlistDir);
      final List<File> songFiles = files.songs;

      // 更新日時は追加日順の並べ替えに、大きさと合わせてキャッシュの
      // 照合にも使う。1曲ずつ待つと曲数分直列になるため並列に取得する。
      final List<FileStat> stats = await Future.wait(
        songFiles.map((file) => file.stat()),
      );

      // メタデータは保存済みの値を使い、新しい曲・変わった曲だけを読む
      final SongMetadataCache cache = SongMetadataCache.instance;
      final List<SongMetadata?> metadataList = await Future.wait([
        for (int i = 0; i < songFiles.length; i++)
          cache.get(songFiles[i].path, stats[i]),
      ]);
      final List<int> missing = [
        for (int i = 0; i < songFiles.length; i++)
          if (metadataList[i] == null &&
              stats[i].type != FileSystemEntityType.notFound)
            i,
      ];
      if (missing.isNotEmpty) {
        final List<SongMetadata>? fetched = await _fetchMetadata([
          for (final int i in missing) songFiles[i].path,
        ]);
        if (fetched != null) {
          for (int j = 0; j < missing.length; j++) {
            final int i = missing[j];
            metadataList[i] = fetched[j];
            await cache.put(songFiles[i].path, stats[i], fetched[j]);
          }
        }
      }

      List<Song> songs = [];
      for (int i = 0; i < songFiles.length; i++) {
        final File songFile = songFiles[i];
        final SongMetadata? metadata = metadataList[i];
        final String songName = p.basenameWithoutExtension(songFile.path);
        songs.add(
          Song(
            metadata?.title.isNotEmpty == true ? metadata!.title : songName,
            metadata?.album.isNotEmpty == true ? metadata!.album : playlistName,
            metadata?.artist ?? '',
            songFile.path,
            files.sidecarThumbnailOf(songFile),
            stats[i].type == FileSystemEntityType.notFound
                ? null
                : stats[i].modified,
          ),
        );
      }
      _songsCache[playlistName] = songs;
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

  /// 曲ごとに1回ずつMethodChannelを呼ぶと、曲数が多いプレイリストで
  /// ネイティブ側とのIPCラウンドトリップが直列に積み重なり著しく遅くなる。
  /// 全ファイルパスをまとめて1回のバッチ呼び出しで処理する。読めなければ null。
  Future<List<SongMetadata>?> _fetchMetadata(List<String> paths) async {
    try {
      final List<Object?>? result = await _methodChannel
          .invokeMethod<List<Object?>>('getAudioMetadataBatch', {
            'paths': paths,
          });
      if (result == null || result.length != paths.length) return null;
      return [
        for (final Object? item in result)
          (
            title: (item is Map ? item['title'] as String? : null) ?? '',
            album: (item is Map ? item['album'] as String? : null) ?? '',
            artist: (item is Map ? item['artist'] as String? : null) ?? '',
          ),
      ];
    } catch (_) {
      return null;
    }
  }

  /// フォルダの中を一度だけ一覧し、曲と、曲と同じ名前の画像を探す。
  /// 曲ごとに画像の有無を調べると、曲数×拡張子の数だけファイルを開くことになる。
  static Future<_PlaylistFiles> _listFiles(Directory playlistDir) async {
    final List<File> songs = [];
    final Set<String> others = {};
    await for (final FileSystemEntity entity in playlistDir.list(
      recursive: true,
    )) {
      if (entity is! File) continue;
      if (p.extension(entity.path).toLowerCase() == '.mp3') {
        songs.add(entity);
      } else {
        others.add(entity.path);
      }
    }
    songs.sort((a, b) => a.path.compareTo(b.path));
    return _PlaylistFiles(songs, others);
  }
}

class _PlaylistFiles {
  const _PlaylistFiles(this.songs, this._otherPaths);

  final List<File> songs;
  final Set<String> _otherPaths;

  String sidecarThumbnailOf(File songFile) {
    final String basePath = p.withoutExtension(songFile.path);
    for (final String extension in ['jpg', 'jpeg', 'png', 'webp']) {
      final String path = '$basePath.$extension';
      if (_otherPaths.contains(path)) return path;
    }
    return '';
  }
}

/// ホームとライブラリに出す、プレイリストの一覧と各プレイリストの曲。
/// 曲はメタデータを読まない軽量版(ネイティブ呼び出しなし)。
class LibrarySnapshot {
  const LibrarySnapshot(this.playlists, this.songsPerPlaylist);

  final List<Playlist> playlists;
  final List<List<Song>> songsPerPlaylist;

  /// 最後に読んだもの。画面を作り直したときにすぐ表示するため。
  static LibrarySnapshot? latest;

  static Future<LibrarySnapshot>? _loading;
  static bool _warmedUp = false;

  /// 読み込む。ホームとライブラリが同時に呼んでも1回だけ読む。
  static Future<LibrarySnapshot> load() =>
      _loading ??= _load().whenComplete(() => _loading = null);

  static Future<LibrarySnapshot> _load() async {
    final List<String> names = await PlaylistsManager().getPlaylistNames();
    final List<List<Song>> songsPerPlaylist = await Future.wait(
      names.map((name) => PlaylistManager(name).getSongsWithoutMetadata()),
    );
    if (!_warmedUp) {
      _warmedUp = true;
      unawaited(_warmUp(names));
    }
    return latest = LibrarySnapshot([
      for (int i = 0; i < names.length; i++)
        Playlist(names[i], songsPerPlaylist[i].length),
    ], songsPerPlaylist);
  }

  /// 起動後に一度、各プレイリストの曲(メタデータ込み)を順に読んでおく。
  /// プレイリストを開いたときに読み込みを待たずに済む。
  static Future<void> _warmUp(List<String> names) async {
    for (final String name in names) {
      if (PlaylistManager.cachedSongs(name) != null) continue;
      await PlaylistManager(name).getPlaylistSongs(name);
    }
  }
}
