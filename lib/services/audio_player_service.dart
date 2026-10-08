import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/services/artwork_cache.dart';
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

  final AudioPlayer player = AudioPlayer();

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
      // 通知に出す画像は最初の曲の分だけ待ち、残りは再生を始めてから用意する
      final ArtworkCache artwork = ArtworkCache.instance;
      await artwork.load(_songs[clampedIndex]);
      final List<AudioSource> children = [
        for (int i = 0; i < _songs.length; i++)
          AudioSource.uri(
            Uri.file(_songs[i].path),
            tag: MediaItem(
              id: _songs[i].path,
              title: _songs[i].title,
              artist: _songs[i].artist.isEmpty ? null : _songs[i].artist,
              album: _songs[i].album.isEmpty ? null : _songs[i].album,
              artUri: artwork.uriFor(_songs[i]),
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
    unawaited(ArtworkCache.instance.prefetch(_songs, startAt: clampedIndex));
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

  /// [startIndex] の曲(省略時はランダム)から始めて、シャッフル再生する。
  Future<void> playShuffled(List<Song> songs, {int? startIndex}) async {
    if (songs.isEmpty) return;
    await loadPlaylist(
      songs,
      startIndex ?? Random().nextInt(songs.length),
      autoPlay: false,
    );
    await player.shuffle();
    await player.setShuffleModeEnabled(true);
    unawaited(player.play());
  }

  /// 先頭から曲順どおりに再生するときなどに、シャッフルを切る。
  Future<void> setShuffleModeEnabled(bool enabled) async {
    if (player.shuffleModeEnabled == enabled) return;
    if (enabled) await player.shuffle();
    await player.setShuffleModeEnabled(enabled);
  }

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

  bool _isSamePlaylist(List<Song> songs) {
    if (_songs.length != songs.length) return false;
    for (int i = 0; i < songs.length; i++) {
      if (_songs[i].path != songs[i].path) return false;
    }
    return true;
  }
}
