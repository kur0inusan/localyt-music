import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/screens/song_player_screen.dart';
import 'package:localyt_music/services/audio_player_service.dart';
import 'package:localyt_music/widgets/song_thumbnail.dart';

/// 画面下部に表示する再生中ミニプレイヤー。
///
/// 再生中の曲がない場合は何も表示しない。タップするとフル再生画面を開く。
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final AudioPlayerService audioService = AudioPlayerService.instance;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return StreamBuilder<int?>(
      stream: audioService.currentIndexStream,
      initialData: audioService.currentIndex,
      builder: (context, indexSnapshot) {
        final List<Song> songs = audioService.songs;
        final int? index = indexSnapshot.data;
        if (songs.isEmpty ||
            index == null ||
            index < 0 ||
            index >= songs.length) {
          return const SizedBox.shrink();
        }
        final Song song = songs[index];

        return Material(
          color: colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SongPlayerScreen(songs: songs, initialIndex: index, autoPlay: false),
                ),
              );
            },
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    SongThumbnail(song: song),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (song.artist.isNotEmpty)
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: audioService.playerStateStream,
                      initialData: audioService.player.playerState,
                      builder: (context, snapshot) {
                        final PlayerState? state = snapshot.data;
                        final bool isBuffering =
                            state?.processingState ==
                                ProcessingState.loading ||
                            state?.processingState ==
                                ProcessingState.buffering;
                        final bool isPlaying = state?.playing ?? false;

                        if (isBuffering) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        }

                        return IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          onPressed: audioService.playPause,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: audioService.seekToNext,
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
