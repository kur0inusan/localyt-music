import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/screens/song_player_screen.dart';
import 'package:localyt_music/services/audio_player_service.dart';
import 'package:localyt_music/theme/app_palette.dart';
import 'package:localyt_music/utils/display_title.dart';
import 'package:localyt_music/widgets/artwork.dart';
import 'package:localyt_music/widgets/glass_surface.dart';

/// 下タブの上に浮かぶミニプレイヤー。下端の細い線で再生位置を示す。
///
/// 再生中の曲がない場合は何も表示しない。タップするか上へ引くとプレイヤーを開く。
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  static const double height = 60;

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  /// 上へ引いて開く距離と、離したときに開く速さ。
  static const double _openDistance = 24;
  static const double _openVelocity = 300;

  /// 上へ引いた量。開いたら null にして、同じ指で二度開かない。
  double? _pull = 0;

  void _open() {
    _pull = null;
    SongPlayerScreen.openCurrent(context);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final double? pull = _pull;
    if (pull == null) return;
    _pull = pull - details.delta.dy;
    if (_pull! >= _openDistance) _open();
  }

  void _onDragEnd(DragEndDetails details) {
    if (_pull != null && details.velocity.pixelsPerSecond.dy < -_openVelocity) {
      _open();
    }
    _pull = 0;
  }

  @override
  Widget build(BuildContext context) {
    final AudioPlayerService audioService = AudioPlayerService.instance;
    final AppPalette palette = AppPalette.of(context);

    return StreamBuilder<int?>(
      stream: audioService.currentIndexStream,
      initialData: audioService.currentIndex,
      builder: (context, indexSnapshot) {
        final Song? song = audioService.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onVerticalDragStart: (_) => _pull = 0,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: GlassSurface(
            borderRadius: palette.radiusMini,
            height: MiniPlayer.height,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _open,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          Artwork(
                            song: song,
                            height: 40,
                            radius: palette.radiusArtSmall,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayTitle(song),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: palette.text,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  song.artist.isNotEmpty
                                      ? song.artist
                                      : song.album,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _PlayPauseButton(color: palette.text),
                          IconButton(
                            tooltip: '次の曲',
                            icon: const Icon(
                              Symbols.skip_next_rounded,
                              size: 26,
                            ),
                            onPressed: audioService.seekToNext,
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _ProgressLine(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final AudioPlayerService audioService = AudioPlayerService.instance;
    return StreamBuilder<PlayerState>(
      stream: audioService.playerStateStream,
      initialData: audioService.player.playerState,
      builder: (context, snapshot) {
        final PlayerState? state = snapshot.data;
        final bool isBuffering =
            state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;
        if (isBuffering) {
          return const SizedBox(
            width: 44,
            height: 44,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final bool isPlaying = state?.playing ?? false;
        return IconButton(
          tooltip: isPlaying ? '一時停止' : '再生',
          icon: Icon(
            isPlaying ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
            size: 28,
            color: color,
          ),
          onPressed: audioService.playPause,
        );
      },
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine();

  @override
  Widget build(BuildContext context) {
    final AudioPlayerService audioService = AudioPlayerService.instance;
    final AppPalette palette = AppPalette.of(context);
    return StreamBuilder<Duration>(
      stream: audioService.positionStream,
      builder: (context, snapshot) {
        final Duration? duration = audioService.player.duration;
        final double fraction = duration == null || duration.inMilliseconds == 0
            ? 0
            : ((snapshot.data ?? Duration.zero).inMilliseconds /
                      duration.inMilliseconds)
                  .clamp(0.0, 1.0);
        return RepaintBoundary(
          child: SizedBox(
            height: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: palette.text.withValues(alpha: 0.12)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: ColoredBox(color: palette.accent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
