import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:localyt_music/models/song.dart';

/// アプリ全体で共有する単一の [AudioPlayer] を保持するサービス。
///
/// just_audio_background はプレイヤーを1インスタンスのみサポートするため、
/// 画面をまたいでバックグラウンド再生を継続できるようシングルトンとして扱う。
class AudioPlayerService {
  AudioPlayerService._internal() {
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        player.pause();
        player.seek(Duration.zero, index: 0);
      }
    });
  }

  static final AudioPlayerService instance = AudioPlayerService._internal();

  static const MethodChannel _methodChannel = MethodChannel(
    'com.kuroinusan.localyt_music/youtubedl',
  );

  final AudioPlayer player = AudioPlayer();

  final Map<String, Uint8List?> _thumbnailCache = {};
  final Map<String, Future<Uint8List?>> _thumbnailLoaders = {};

  List<Song> _songs = const [];

  List<Song> get songs => _songs;

  bool get hasActivePlaylist => _songs.isNotEmpty;

  int? get currentIndex => player.currentIndex;

  Song? get currentSong {
    final int? index = currentIndex;
    if (index == null || index < 0 || index >= _songs.length) return null;
    return _songs[index];
  }

  Stream<int?> get currentIndexStream => player.currentIndexStream;
  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;

  /// 指定したプレイリストの [initialIndex] 番目の曲から再生を開始する。
  /// 既に同じプレイリストを読み込み済みの場合は、曲の切り替えのみ行う。
  Future<void> playPlaylist(List<Song> songs, int initialIndex) async {
    if (songs.isEmpty) return;
    final int clampedIndex = initialIndex.clamp(0, songs.length - 1);

    if (_isSamePlaylist(songs)) {
      if (player.currentIndex != clampedIndex) {
        await player.seek(Duration.zero, index: clampedIndex);
      }
      unawaited(player.play());
      return;
    }

    _songs = List.unmodifiable(songs);
    final List<Uri?> artUris = await Future.wait(
      _songs.map(_resolveArtUri),
    );
    final List<AudioSource> children = [
      for (int i = 0; i < _songs.length; i++)
        AudioSource.uri(
          Uri.file(_songs[i].path),
          tag: MediaItem(
            id: _songs[i].path,
            title: _songs[i].title,
            artist: _songs[i].artist.isEmpty ? null : _songs[i].artist,
            album: _songs[i].album.isEmpty ? null : _songs[i].album,
            artUri: artUris[i],
          ),
        ),
    ];

    await player.setAudioSources(children, initialIndex: clampedIndex);
    unawaited(player.play());
  }

  Future<void> playPause() async {
    if (player.playing) {
      await player.pause();
    } else {
      unawaited(player.play());
    }
  }

  Future<void> seekToPrevious() async {
    if (player.hasPrevious) {
      await player.seekToPrevious();
    } else {
      await player.seek(Duration.zero);
    }
  }

  Future<void> seekToNext() async {
    if (player.hasNext) {
      await player.seekToNext();
    }
  }

  Future<void> seek(Duration position) => player.seek(position);

  /// 曲のサムネイル画像を取得する。サイドカー画像があればそれを、
  /// なければ音声ファイルに埋め込まれた画像を読み込む。結果はキャッシュされる。
  Future<Uint8List?> loadThumbnail(Song song) {
    if (_thumbnailCache.containsKey(song.path)) {
      return Future.value(_thumbnailCache[song.path]);
    }
    return _thumbnailLoaders[song.path] ??= _fetchThumbnail(song).then((
      bytes,
    ) {
      _thumbnailCache[song.path] = bytes;
      _thumbnailLoaders.remove(song.path);
      return bytes;
    });
  }

  Future<Uint8List?> _fetchThumbnail(Song song) async {
    if (song.thumbnailPath.isNotEmpty) {
      final File file = File(song.thumbnailPath);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }
    try {
      return await _methodChannel.invokeMethod<Uint8List>(
        'getAudioThumbnail',
        {'path': song.path},
      );
    } catch (_) {
      return null;
    }
  }

  /// 通知・ロック画面に表示するアートワークの [Uri] を解決する。
  /// サイドカー画像があればそのファイルを、なければ埋め込み画像を
  /// キャッシュディレクトリに書き出して利用する。
  Future<Uri?> _resolveArtUri(Song song) async {
    if (song.thumbnailPath.isNotEmpty) {
      final File file = File(song.thumbnailPath);
      if (await file.exists()) {
        return Uri.file(file.path);
      }
    }

    final Uint8List? bytes = await loadThumbnail(song);
    if (bytes == null) return null;

    final Directory tempDir = await getTemporaryDirectory();
    final Directory artDir = Directory(p.join(tempDir.path, 'artwork'));
    if (!await artDir.exists()) {
      await artDir.create(recursive: true);
    }
    final File artFile = File(
      p.join(artDir.path, '${song.path.hashCode}.jpg'),
    );
    if (!await artFile.exists()) {
      await artFile.writeAsBytes(bytes, flush: true);
    }
    return Uri.file(artFile.path);
  }

  bool _isSamePlaylist(List<Song> songs) {
    if (_songs.length != songs.length) return false;
    for (int i = 0; i < songs.length; i++) {
      if (_songs[i].path != songs[i].path) return false;
    }
    return true;
  }
}
