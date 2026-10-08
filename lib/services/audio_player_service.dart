import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/services/play_history_service.dart';

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
    player.currentIndexStream.listen((_) => _onPlaybackChanged());
    player.playingStream.listen((_) => _onPlaybackChanged());
    player.positionStream.listen((_) {
      if (!player.playing) return;
      if (DateTime.now().difference(_lastResumeSave) < _resumeSaveInterval) {
        return;
      }
      _saveResumePoint();
    });
  }

  static const Duration _resumeSaveInterval = Duration(seconds: 10);

  static final AudioPlayerService instance = AudioPlayerService._internal();

  static const MethodChannel _methodChannel = MethodChannel(
    'com.kuroinusan.localyt_music/youtubedl',
  );

  final AudioPlayer player = AudioPlayer();

  final Map<String, Uint8List?> _thumbnailCache = {};
  final Map<String, Future<Uint8List?>> _thumbnailLoaders = {};

  List<Song> _songs = const [];

  // キューの差し替え中は currentIndex が旧キューを指すため、履歴・位置を記録しない。
  bool _isReplacingQueue = false;
  String? _lastRecordedPath;
  DateTime _lastResumeSave = DateTime.fromMillisecondsSinceEpoch(0);

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
  Stream<bool> get shuffleModeEnabledStream => player.shuffleModeEnabledStream;
  Stream<LoopMode> get loopModeStream => player.loopModeStream;

  bool get shuffleModeEnabled => player.shuffleModeEnabled;
  LoopMode get loopMode => player.loopMode;

  /// 指定したプレイリストの [initialIndex] 番目の曲から再生を開始する。
  /// 既に同じプレイリストを読み込み済みの場合は、曲の切り替えのみ行う。
  Future<void> playPlaylist(List<Song> songs, int initialIndex) async {
    await loadPlaylist(songs, initialIndex, autoPlay: true);
  }

  /// プレイリストを読み込む。[autoPlay] が false の場合は再生を開始しない。
  /// [initialPosition] を指定すると、その位置から再生する(続きから再生用)。
  Future<void> loadPlaylist(
    List<Song> songs,
    int initialIndex, {
    bool autoPlay = true,
    Duration? initialPosition,
  }) async {
    if (songs.isEmpty) return;
    final int clampedIndex = initialIndex.clamp(0, songs.length - 1);

    if (_isSamePlaylist(songs)) {
      if (player.currentIndex != clampedIndex || initialPosition != null) {
        await player.seek(
          initialPosition ?? Duration.zero,
          index: clampedIndex,
        );
      }
      if (autoPlay) {
        unawaited(player.play());
      }
      return;
    }

    _isReplacingQueue = true;
    try {
      _songs = List.unmodifiable(songs);
      final List<Uri?> artUris = await _resolveArtUris(_songs);
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

      await player.setAudioSources(
        children,
        initialIndex: clampedIndex,
        initialPosition: initialPosition,
      );
    } finally {
      _isReplacingQueue = false;
    }
    PlayHistoryService.instance.saveResumeQueue(_songs);
    _saveResumePoint();
    if (autoPlay) {
      unawaited(player.play());
    }
  }

  /// 前回終了時の再生キューと位置を復元して再生する。復元できなければ false。
  Future<bool> resumeLastSession() async {
    final PlayHistoryService history = PlayHistoryService.instance;
    final ResumePoint? point = history.resumePoint;
    if (point == null) return false;

    final List<Song> queue = (await history.loadResumeQueue())
        .where((song) => File(song.path).existsSync())
        .toList();
    final int index = queue.indexWhere((song) => song.path == point.song.path);
    if (index < 0) {
      // 再生中に履歴を削除した後などキューが残っていなければ、その曲だけで再開する
      if (!File(point.song.path).existsSync()) return false;
      await loadPlaylist([point.song], 0, initialPosition: point.position);
      return true;
    }

    await loadPlaylist(queue, index, initialPosition: point.position);
    return true;
  }

  /// 再生中の曲が切り替わったとき、または再生が始まったときに履歴へ記録する。
  /// 一時停止→再開や1曲リピートでは同じ曲を重複して数えない。
  void _onPlaybackChanged() {
    if (_isReplacingQueue) return;
    final Song? song = currentSong;
    if (song == null) return;
    if (player.playing && song.path != _lastRecordedPath) {
      _lastRecordedPath = song.path;
      PlayHistoryService.instance.recordPlay(song);
    }
    _saveResumePoint();
  }

  void _saveResumePoint() {
    if (_isReplacingQueue) return;
    final int? index = currentIndex;
    final Song? song = currentSong;
    if (index == null || song == null) return;
    _lastResumeSave = DateTime.now();
    PlayHistoryService.instance.saveResumePoint(song, index, player.position);
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

  /// シャッフル再生のオン/オフを切り替える。オンにする際は再生順をシャッフルし直す。
  Future<void> toggleShuffleMode() async {
    final bool enable = !player.shuffleModeEnabled;
    if (enable) {
      await player.shuffle();
    }
    await player.setShuffleModeEnabled(enable);
  }

  /// 繰り返し再生モードを「なし → 全曲リピート → 1曲リピート → なし」の順に切り替える。
  Future<void> cycleLoopMode() async {
    switch (player.loopMode) {
      case LoopMode.off:
        await player.setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        await player.setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        await player.setLoopMode(LoopMode.off);
        break;
    }
  }

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

  /// 曲のアートワークURIをまとめて解決する。全曲を一度に並列実行すると
  /// 曲数の多いプレイリストでネイティブ呼び出しが大量に同時発火してしまう
  /// ため、一定数ずつバッチに分けて処理する。
  Future<List<Uri?>> _resolveArtUris(List<Song> songs) async {
    const int batchSize = 6;
    final List<Uri?> results = List<Uri?>.filled(songs.length, null);
    for (int start = 0; start < songs.length; start += batchSize) {
      final int end = (start + batchSize > songs.length)
          ? songs.length
          : start + batchSize;
      final List<Uri?> batch = await Future.wait(
        songs.sublist(start, end).map(_resolveArtUri),
      );
      results.setRange(start, end, batch);
    }
    return results;
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
