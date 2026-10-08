import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/services/audio_player_service.dart';
import 'package:localyt_music/theme/app_palette.dart';
import 'package:localyt_music/theme/app_theme.dart';
import 'package:localyt_music/utils/display_title.dart';
import 'package:localyt_music/utils/format.dart';
import 'package:localyt_music/widgets/app_buttons.dart';
import 'package:localyt_music/widgets/artwork.dart';
import 'package:localyt_music/widgets/glass_surface.dart';
import 'package:localyt_music/widgets/marquee_text.dart';
import 'package:localyt_music/widgets/song_row.dart';

/// 全画面のプレイヤー。背景にジャケットの色をぼかして敷き、角丸のジャケットの
/// 下に曲名と再生位置のバーを置く(バーでシークできる)。
class SongPlayerScreen extends StatefulWidget {
  final List<Song> songs;
  final int initialIndex;
  final bool autoPlay;

  /// true でシャッフル再生、false で曲順どおりに再生する。null なら今の設定のまま。
  final bool? shuffle;

  const SongPlayerScreen({
    super.key,
    required this.songs,
    required this.initialIndex,
    this.autoPlay = true,
    this.shuffle,
  });

  /// [songs] の [index] 番目から再生してプレイヤーを開く。下から持ち上がり、
  /// 下へ引くと閉じる。曲の読み込みは開いてから行う。
  static Future<void> open(
    BuildContext context,
    List<Song> songs,
    int index, {
    bool autoPlay = true,
    bool? shuffle,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      _PlayerRoute(
        builder: (context) => SongPlayerScreen(
          songs: songs,
          initialIndex: index,
          autoPlay: autoPlay,
          shuffle: shuffle,
        ),
      ),
    );
  }

  /// 再生中のキューのままプレイヤーを開く(再生状態は変えない)。
  static Future<void> openCurrent(BuildContext context) {
    final AudioPlayerService audioService = AudioPlayerService.instance;
    final int? index = audioService.currentIndex;
    if (audioService.songs.isEmpty || index == null) return Future.value();
    return open(context, audioService.songs, index, autoPlay: false);
  }

  @override
  State<SongPlayerScreen> createState() => _SongPlayerScreenState();
}

/// 縦に引いている指が、何の操作になったか。
enum _DragMode { none, dismiss, queue, done }

class _SongPlayerScreenState extends State<SongPlayerScreen> {
  /// 上へ引いてキューを開く距離と、離したときに開く速さ。
  static const double _queuePullDistance = 48;
  static const double _queueFlingVelocity = 500;

  final AudioPlayerService _audioService = AudioPlayerService.instance;

  _PlayerRoute? _route;
  _DragMode _dragMode = _DragMode.none;
  double _queuePull = 0;

  StreamSubscription<int?>? _currentIndexSubscription;
  int? _currentIndex;
  bool _isLoading = true;
  String? _errorText;

  Song? get _currentSong {
    // 読み込みを待たずに、開いた曲をすぐ表示する
    if (_isLoading && widget.songs.isNotEmpty) {
      return widget.songs[widget.initialIndex.clamp(
        0,
        widget.songs.length - 1,
      )];
    }
    final List<Song> songs = _audioService.songs;
    final int? index = _currentIndex;
    if (index == null || index < 0 || index >= songs.length) return null;
    return songs[index];
  }

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    _route = route is _PlayerRoute ? route : null;
  }

  @override
  void dispose() {
    _currentIndexSubscription?.cancel();
    super.dispose();
  }

  /// 下へ引くと画面ごと指について下がり、上へ引くと再生キューを開く。
  /// 向きは引き始めで決め、途中で向きを変えても操作は切り替えない。
  void _onDragUpdate(double dy) {
    switch (_dragMode) {
      case _DragMode.none:
        if (dy > 0) {
          if (_route?.startDrag() != true) return;
          _dragMode = _DragMode.dismiss;
          _route!.updateDrag(dy / MediaQuery.sizeOf(context).height);
        } else if (dy < 0) {
          _dragMode = _DragMode.queue;
          _queuePull = -dy;
        }
      case _DragMode.dismiss:
        _route!.updateDrag(dy / MediaQuery.sizeOf(context).height);
      case _DragMode.queue:
        _queuePull -= dy;
        if (_queuePull >= _queuePullDistance) {
          _dragMode = _DragMode.done;
          _showQueue();
        }
      case _DragMode.done:
        break;
    }
  }

  void _onDragEnd(double velocity) {
    switch (_dragMode) {
      case _DragMode.dismiss:
        _route!.endDrag(velocity / MediaQuery.sizeOf(context).height);
      case _DragMode.queue:
        if (velocity < -_queueFlingVelocity) _showQueue();
      case _DragMode.none:
      case _DragMode.done:
        break;
    }
    _dragMode = _DragMode.none;
  }

  /// 曲名などが画面に収まらずスクロールできるときは、端からさらに
  /// 引いた分を、画面を引く操作として扱う。
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      _onDragUpdate(-notification.overscroll);
    } else if (notification is ScrollEndNotification &&
        _dragMode != _DragMode.none) {
      _onDragEnd(notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
    }
    return false;
  }

  Future<void> _loadPlaylist() async {
    if (widget.songs.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorText = '曲がありません';
      });
      return;
    }

    try {
      await _waitForOpening();
      if (widget.shuffle == true) {
        await _audioService.playShuffled(
          widget.songs,
          startIndex: widget.initialIndex,
        );
      } else {
        if (widget.shuffle == false) {
          await _audioService.setShuffleModeEnabled(false);
        }
        await _audioService.loadPlaylist(
          widget.songs,
          widget.initialIndex,
          autoPlay: widget.autoPlay,
        );
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentIndex = _audioService.currentIndex;
      });
      _currentIndexSubscription = _audioService.currentIndexStream.listen((
        index,
      ) {
        if (!mounted || index == _currentIndex) return;
        setState(() {
          _currentIndex = index;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = '再生できませんでした: $e';
      });
    }
  }

  /// 開くアニメーションが終わるまで待つ。
  ///
  /// 曲の一覧を再生機能へ渡す処理は、Android 側で画面の描画と同じスレッドを
  /// 一時的にふさぐので、動いている途中に行うと出だしが引っかかる。
  Future<void> _waitForOpening() async {
    // ルートは最初の build の前に決まるので、1フレーム待ってから見る
    await WidgetsBinding.instance.endOfFrame;
    final Animation<double>? animation = _route?.animation;
    if (animation == null || animation.status != AnimationStatus.forward) {
      return;
    }
    final Completer<void> opened = Completer<void>();
    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.forward) return;
      animation.removeStatusListener(onStatus);
      opened.complete();
    }

    animation.addStatusListener(onStatus);
    await opened.future;
  }

  void _showQueue() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _QueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Song? song = _currentSong;

    final Widget page = AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayFor(palette),
      child: Scaffold(
        backgroundColor: palette.bg,
        body: Stack(
          children: [
            if (song != null)
              Positioned.fill(child: ArtworkBackdrop(song: song)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.bg.withValues(alpha: 0.2),
                      palette.bg.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(title: song?.album ?? ''),
                  Expanded(child: _buildBody(palette, song)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onVerticalDragUpdate: (details) => _onDragUpdate(details.delta.dy),
      onVerticalDragEnd: (details) =>
          _onDragEnd(details.velocity.pixelsPerSecond.dy),
      onVerticalDragCancel: () => _onDragEnd(0),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        // 再生操作と「次」のすりガラスをまとめて描く
        child: BackdropGroup(child: page),
      ),
    );
  }

  Widget _buildBody(AppPalette palette, Song? song) {
    // 読み込み中はプレイヤーがまだ前の曲を指しているので、その再生位置を出さない
    final bool idle =
        _isLoading && song?.path != _audioService.currentSong?.path;
    if (_errorText != null || song == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorText ?? '再生できませんでした',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ジャケット以外(揺れるバー・曲名・シークバー・操作)にはおよそ350の高さが要る
              final double artSize = math
                  .min(
                    280.0,
                    math.min(
                      constraints.maxWidth - 48,
                      constraints.maxHeight - 350,
                    ),
                  )
                  .clamp(160.0, 280.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  children: [
                    _CoverArt(song: song, size: artSize),
                    const SizedBox(height: 16),
                    // 再生中は毎フレーム描き直すので、他と分けておく
                    const RepaintBoundary(child: _Visualizer()),
                    const SizedBox(height: 16),
                    MarqueeText(
                      displayTitle(song),
                      textAlign: TextAlign.center,
                      style: AppFonts.displayStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist.isNotEmpty ? song.artist : song.album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: palette.textMuted),
                    ),
                    const SizedBox(height: 14),
                    RepaintBoundary(child: _SeekBar(idle: idle)),
                    const SizedBox(height: 12),
                    const _Controls(),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
          child: _NextUpPill(onTap: _showQueue),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: '閉じる',
              icon: const Icon(Symbols.expand_more_rounded, size: 28),
              onPressed: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: palette.textMuted),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

/// 角丸の四角いジャケット。浮いて見えるよう、うっすら影を付ける。
class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.song, required this.size});

  final Song song;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(palette.radiusArtLarge),
        boxShadow: [
          BoxShadow(
            color: palette.glassShadow,
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Artwork(song: song, height: size, radius: palette.radiusArtLarge),
    );
  }
}

/// 再生位置のバーと、その下の経過時間・曲の長さ。バーをなぞる・タップすると
/// シークする。なぞっている間は指の位置の時間を出し、離したときに移動する。
class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.idle});

  /// 曲を読み込み中で、再生位置をまだ出せない。
  final bool idle;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// なぞっている間の位置(ミリ秒)。離して移動し終えたら null に戻す。
  double? _dragMs;

  Future<void> _seekTo(double ms) async {
    await AudioPlayerService.instance.seek(Duration(milliseconds: ms.round()));
    // 移動し終えるまで指の位置を出しておく(古い再生位置へ一瞬戻らないように)
    if (mounted) setState(() => _dragMs = null);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AudioPlayerService audioService = AudioPlayerService.instance;
    return StreamBuilder<Duration>(
      stream: audioService.positionStream,
      builder: (context, snapshot) {
        final Duration? duration = widget.idle
            ? null
            : audioService.player.duration;
        final double totalMs = duration?.inMilliseconds.toDouble() ?? 0;
        final bool enabled = totalMs > 0;
        final double positionMs = enabled
            ? (_dragMs ??
                      (snapshot.data ?? Duration.zero).inMilliseconds
                          .toDouble())
                  .clamp(0, totalMs)
            : 0;
        final TextStyle timeStyle = AppFonts.monoStyle(
          fontSize: 12,
          color: palette.textMuted,
        );

        return Column(
          children: [
            SizedBox(
              height: 32,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: palette.accent,
                  inactiveTrackColor: palette.track,
                  disabledActiveTrackColor: palette.track,
                  disabledInactiveTrackColor: palette.track,
                  thumbColor: palette.accent,
                  disabledThumbColor: palette.track,
                  overlayColor: palette.accent.withValues(alpha: 0.16),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 18,
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Slider(
                  value: positionMs,
                  max: enabled ? totalMs : 1,
                  semanticFormatterCallback: (value) =>
                      formatPlaybackTime(Duration(milliseconds: value.round())),
                  onChanged: enabled
                      ? (value) => setState(() => _dragMs = value)
                      : null,
                  onChangeEnd: enabled ? _seekTo : null,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatPlaybackTime(
                    Duration(milliseconds: positionMs.round()),
                  ),
                  style: timeStyle,
                ),
                Text(
                  formatPlaybackTime(duration ?? Duration.zero),
                  style: timeStyle,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// 曲名の上で揺れる短いバー。再生位置とは関係のない飾りで、常に表示する。
/// 音が出ている間だけ揺れ、一時停止・読み込み中・再生し終えたときは、
/// 低くそろった形へ静かに収まって止まる(音の大きさとは連動しない)。
class _Visualizer extends StatefulWidget {
  const _Visualizer();

  @override
  State<_Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<_Visualizer>
    with TickerProviderStateMixin {
  /// 揺れの時間。60秒で1周する。
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  /// 揺れの大きさ(0で止まった形、1で揺れている)。
  late final AnimationController _activity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  StreamSubscription<PlayerState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    final AudioPlayer player = AudioPlayerService.instance.player;
    _apply(player.playerState, animate: false);
    _stateSubscription = player.playerStateStream.listen(_apply);
  }

  /// 再生の指示が出ていても、読み込み中や再生し終えた後は音が出ていない。
  static bool _isSounding(PlayerState state) =>
      state.playing && state.processingState == ProcessingState.ready;

  void _apply(PlayerState state, {bool animate = true}) {
    if (_isSounding(state)) {
      if (!_wave.isAnimating) _wave.repeat();
      if (animate) {
        _activity.forward();
      } else {
        _activity.value = 1;
      }
      return;
    }
    if (!animate) {
      _activity.value = 0;
      _wave.stop();
      return;
    }
    // 揺れを収めきってから時間も止める
    _activity.reverse().whenCompleteOrCancel(() {
      if (mounted && _activity.isDismissed) _wave.stop();
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _wave.dispose();
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: _BarsPainter.totalWidth,
        height: 26,
        child: CustomPaint(
          painter: _BarsPainter(
            wave: _wave,
            activity: _activity,
            color: palette.accent,
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.wave,
    required this.activity,
    required this.color,
  }) : super(repaint: Listenable.merge([wave, activity]));

  static const int _count = 14;
  static const double _barWidth = 4;
  static const double _gap = 3;
  static const double totalWidth = _count * _barWidth + (_count - 1) * _gap;

  final Animation<double> wave;
  final Animation<double> activity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 60秒で1周するコントローラの値を秒に直す
    final double seconds = wave.value * 60;
    final double amount = Curves.easeOut.transform(activity.value);
    final double left = (size.width - totalWidth) / 2;
    final Paint paint = Paint()..color = color;

    for (int i = 0; i < _count; i++) {
      // 中央ほど高い山なりの形
      final double c = (i - (_count - 1) / 2).abs() / ((_count - 1) / 2);
      final double maxHeight = size.height * (1 - c * 0.55);
      // バーごとに周期と位相をずらして 0.25〜1 の間で伸び縮みさせる
      final double period = 0.7 + ((i * 37) % 9) / 10;
      final double phase = ((i * 53) % 13) / 10;
      final double swing =
          0.5 - 0.5 * math.cos(2 * math.pi * (seconds + phase) / (period * 2));
      // 止まっているときは 0.25 でそろえ、揺れの分だけ伸ばす
      final double scale = 0.25 + 0.75 * swing * amount;
      final double height = maxHeight * scale;
      final Rect rect = Rect.fromLTWH(
        left + i * (_barWidth + _gap),
        (size.height - height) / 2,
        _barWidth,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) => oldDelegate.color != color;
}

/// シャッフル / 前 / 再生 / 次 / 繰り返し。すりガラスのカプセルに載せる。
class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AudioPlayerService audioService = AudioPlayerService.instance;

    return GlassSurface(
      borderRadius: 999,
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StreamBuilder<bool>(
            stream: audioService.shuffleModeEnabledStream,
            initialData: audioService.shuffleModeEnabled,
            builder: (context, snapshot) {
              final bool enabled = snapshot.data ?? false;
              return IconButton(
                tooltip: enabled ? 'シャッフル: オン' : 'シャッフル: オフ',
                icon: Icon(
                  Symbols.shuffle_rounded,
                  size: 22,
                  color: enabled ? palette.accent : palette.textFaint,
                ),
                onPressed: audioService.toggleShuffleMode,
              );
            },
          ),
          IconButton(
            tooltip: '前の曲',
            icon: Icon(
              Symbols.skip_previous_rounded,
              size: 34,
              fill: 1,
              color: palette.text,
            ),
            onPressed: audioService.seekToPrevious,
          ),
          StreamBuilder<PlayerState>(
            stream: audioService.playerStateStream,
            initialData: audioService.player.playerState,
            builder: (context, snapshot) {
              final bool isPlaying = snapshot.data?.playing ?? false;
              return PlayButton(
                icon: isPlaying
                    ? Symbols.pause_rounded
                    : Symbols.play_arrow_rounded,
                tooltip: isPlaying ? '一時停止' : '再生',
                size: 64,
                iconSize: 36,
                onPressed: audioService.playPause,
              );
            },
          ),
          IconButton(
            tooltip: '次の曲',
            icon: Icon(
              Symbols.skip_next_rounded,
              size: 34,
              fill: 1,
              color: palette.text,
            ),
            onPressed: audioService.seekToNext,
          ),
          StreamBuilder<LoopMode>(
            stream: audioService.loopModeStream,
            initialData: audioService.loopMode,
            builder: (context, snapshot) {
              final LoopMode mode = snapshot.data ?? LoopMode.off;
              return IconButton(
                tooltip: switch (mode) {
                  LoopMode.off => '繰り返し: オフ',
                  LoopMode.all => '繰り返し: 全曲',
                  LoopMode.one => '繰り返し: 1曲',
                },
                icon: Icon(
                  mode == LoopMode.one
                      ? Symbols.repeat_one_rounded
                      : Symbols.repeat_rounded,
                  size: 22,
                  color: mode == LoopMode.off
                      ? palette.textFaint
                      : palette.accent,
                ),
                onPressed: audioService.cycleLoopMode,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 「次 ○○」の小さなカプセル。タップするか、画面を上へ引くと再生キューを開く。
class _NextUpPill extends StatelessWidget {
  const _NextUpPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AudioPlayerService audioService = AudioPlayerService.instance;
    return StreamBuilder<SequenceState?>(
      stream: audioService.player.sequenceStateStream,
      builder: (context, _) {
        final int? nextIndex = audioService.player.nextIndex;
        final List<Song> songs = audioService.songs;
        final String nextTitle =
            nextIndex != null && nextIndex >= 0 && nextIndex < songs.length
            ? displayTitle(songs[nextIndex])
            : '最後の曲です';
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: GlassSurface(
            borderRadius: 999,
            height: 40,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Symbols.queue_music_rounded,
                        size: 20,
                        color: palette.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '次',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          nextTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: palette.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 再生キュー。再生中の曲と、その後に流れる曲を再生順に並べる。
class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AudioPlayerService audioService = AudioPlayerService.instance;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return StreamBuilder<SequenceState?>(
          stream: audioService.player.sequenceStateStream,
          builder: (context, _) {
            final List<Song> songs = audioService.songs;
            final int? current = audioService.currentIndex;
            final List<int> order = audioService.player.effectiveIndices;
            final int start = current == null ? 0 : order.indexOf(current);
            final List<int> queue = start < 0 ? order : order.sublist(start);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: '次に再生',
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  trailing: Text(
                    '${math.max(0, queue.length - 1)}曲',
                    style: AppFonts.monoStyle(color: palette.textMuted),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom + 12,
                    ),
                    itemCount: queue.length,
                    itemBuilder: (context, i) {
                      final int index = queue[i];
                      if (index < 0 || index >= songs.length) {
                        return const SizedBox.shrink();
                      }
                      return SongRow(
                        song: songs[index],
                        playing: index == current,
                        onTap: () {
                          audioService.player.seek(Duration.zero, index: index);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// プレイヤーのルート。下から持ち上がって開き、下へ引くと指について下がる。
///
/// 引いている間と、離した後に閉じる・戻るまでは、ルートのアニメーションを
/// 曲線をかけずに動かす(指の位置や離したときの勢いと、画面の動きがずれない)。
/// 下がっている間は Navigator が下の画面を透けさせる。
class _PlayerRoute extends PageRoute<void> {
  _PlayerRoute({required this.builder});

  final WidgetBuilder builder;

  /// 離したときに閉じる、引いた量と速さ(どちらも画面の高さに対する割合)。
  static const double _dismissFraction = 0.22;
  static const double _flingVelocity = 1.0;

  /// 閉じるとき・戻るときの最低の速さ(高さ/秒)。ゆっくり離しても
  /// もたつかない。
  static const double _minExitVelocity = 2.5;
  static const double _minSettleVelocity = 1.5;

  /// 指で動かしているか、離した後の続きのアニメーション中か。
  bool _dragging = false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final double shown = _dragging
        ? animation.value
        : Curves.easeOutCubic.transform(animation.value);
    final double offset = (1 - shown) * MediaQuery.sizeOf(context).height;
    return Transform.translate(
      offset: Offset(0, offset),
      child: ClipRRect(
        // 下がるほど上の角を丸め、カードとして持ち上がっている感じを出す
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(math.min(offset / 3, 28)),
        ),
        clipBehavior: offset > 0 ? Clip.antiAlias : Clip.none,
        child: child,
      ),
    );
  }

  /// 引き始め。開閉のアニメーション中などで引けないときは false。
  bool startDrag() {
    final AnimationController? animation = controller;
    if (_dragging || !isCurrent || animation == null || animation.isAnimating) {
      return false;
    }
    _dragging = true;
    navigator!.didStartUserGesture();
    return true;
  }

  /// [delta] は下向きを正とした、画面の高さに対する割合。
  void updateDrag(double delta) {
    controller!.value -= delta;
  }

  /// [velocity] は下向きを正とした、画面の高さ/秒。
  void endDrag(double velocity) {
    final AnimationController animation = controller!;
    final NavigatorState navigator = this.navigator!;
    final bool close =
        isCurrent &&
        (velocity > _flingVelocity ||
            (velocity > -_flingVelocity &&
                1 - animation.value > _dismissFraction));
    if (close) {
      navigator.pop();
      // 離したときの勢いを落とさず、等速で下へ抜ける
      final double speed = math.max(velocity, _minExitVelocity);
      animation.animateBack(
        0,
        duration: _durationOf(animation.value / speed),
        curve: Curves.linear,
      );
    } else {
      // 上向きの勢いから、減速しながら元の位置へ戻る(easeOutCubic の
      // 出だしの速さは平均の3倍なので、そのぶん時間を延ばして合わせる)
      final double speed = math.max(-velocity, _minSettleVelocity);
      animation.animateTo(
        1,
        duration: _durationOf(3 * (1 - animation.value) / speed),
        curve: Curves.easeOutCubic,
      );
    }

    void finish() {
      _dragging = false;
      navigator.didStopUserGesture();
    }

    if (!animation.isAnimating) {
      finish();
      return;
    }
    // 動き終わるまでは曲線をかけないままにする(途中で動きが跳ねないように)
    void onStatus(AnimationStatus status) {
      if (status.isAnimating) return;
      animation.removeStatusListener(onStatus);
      finish();
    }

    animation.addStatusListener(onStatus);
  }

  static Duration _durationOf(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round().clamp(80, 320));
}
