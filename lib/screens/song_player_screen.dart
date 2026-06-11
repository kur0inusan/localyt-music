import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/services/audio_player_service.dart';

class SongPlayerScreen extends StatefulWidget {
  final List<Song> songs;
  final int initialIndex;
  final bool autoPlay;

  const SongPlayerScreen({
    super.key,
    required this.songs,
    required this.initialIndex,
    this.autoPlay = true,
  });

  @override
  State<SongPlayerScreen> createState() => _SongPlayerScreenState();
}

class _SongPlayerScreenState extends State<SongPlayerScreen> {
  final AudioPlayerService _audioService = AudioPlayerService.instance;

  StreamSubscription<int?>? _currentIndexSubscription;
  int? _currentIndex;
  Uint8List? _thumbnail;
  String? _thumbnailLoadedForPath;
  bool _isLoading = true;
  String? _errorText;

  Song? get _currentSong {
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
  void dispose() {
    _currentIndexSubscription?.cancel();
    super.dispose();
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
      await _audioService.loadPlaylist(
        widget.songs,
        widget.initialIndex,
        autoPlay: widget.autoPlay,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentIndex = _audioService.currentIndex;
      });
      _maybeLoadThumbnail();
      _currentIndexSubscription = _audioService.currentIndexStream.listen((
        index,
      ) {
        if (!mounted || index == _currentIndex) return;
        setState(() {
          _currentIndex = index;
        });
        _maybeLoadThumbnail();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = '再生できませんでした: $e';
      });
    }
  }

  void _maybeLoadThumbnail() {
    final Song? song = _currentSong;
    if (song == null) return;
    if (song.thumbnailPath.isNotEmpty &&
        File(song.thumbnailPath).existsSync()) {
      _thumbnailLoadedForPath = song.path;
      setState(() {
        _thumbnail = null;
      });
      return;
    }
    unawaited(_loadEmbeddedThumbnail(song));
  }

  Future<void> _loadEmbeddedThumbnail(Song song) async {
    if (_thumbnailLoadedForPath == song.path) return;
    _thumbnailLoadedForPath = song.path;
    final Uint8List? thumbnail = await _audioService.loadThumbnail(song);
    if (!mounted || _currentSong?.path != song.path) return;
    setState(() {
      _thumbnail = thumbnail;
    });
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);
    final int hours = duration.inHours;
    final String twoDigitSeconds = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$twoDigitSeconds';
    }
    return '$minutes:$twoDigitSeconds';
  }

  Widget _buildArtwork(ColorScheme colorScheme, Song song) {
    if (_thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _thumbnail!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    if (song.thumbnailPath.isNotEmpty) {
      final File thumbnailFile = File(song.thumbnailPath);
      if (thumbnailFile.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            thumbnailFile,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note,
        size: 96,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AudioPlayer player = _audioService.player;
    final Song? currentSong = _currentSong;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorText != null || currentSong == null
            ? Center(
                child: Text(
                  _errorText ?? '再生できませんでした',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _buildArtwork(colorScheme, currentSong),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      currentSong.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        currentSong.artist,
                        currentSong.album,
                      ].where((value) => value.isNotEmpty).join(' - '),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    StreamBuilder<Duration>(
                      stream: _audioService.positionStream,
                      builder: (context, snapshot) {
                        final Duration position =
                            snapshot.data ?? Duration.zero;
                        final Duration duration =
                            player.duration ?? Duration.zero;
                        final double maxMilliseconds = duration.inMilliseconds
                            .toDouble()
                            .clamp(1, double.infinity);
                        final double value = position.inMilliseconds
                            .toDouble()
                            .clamp(0, maxMilliseconds);

                        return Column(
                          children: [
                            Slider(
                              value: value,
                              max: maxMilliseconds,
                              onChanged: duration == Duration.zero
                                  ? null
                                  : (value) {
                                      _audioService.seek(
                                        Duration(
                                          milliseconds: value.round(),
                                        ),
                                      );
                                    },
                            ),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(position)),
                                Text(_formatDuration(duration)),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StreamBuilder<bool>(
                          stream: _audioService.shuffleModeEnabledStream,
                          initialData: _audioService.shuffleModeEnabled,
                          builder: (context, snapshot) {
                            final bool enabled = snapshot.data ?? false;
                            return IconButton(
                              tooltip: 'シャッフル再生',
                              iconSize: 28,
                              color: enabled ? colorScheme.primary : null,
                              onPressed: _audioService.toggleShuffleMode,
                              icon: const Icon(Icons.shuffle),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '前の曲',
                          iconSize: 40,
                          onPressed: _audioService.seekToPrevious,
                          icon: const Icon(Icons.skip_previous),
                        ),
                        const SizedBox(width: 16),
                        StreamBuilder<PlayerState>(
                          stream: _audioService.playerStateStream,
                          builder: (context, snapshot) {
                            final PlayerState? state = snapshot.data;
                            final bool isBuffering =
                                state?.processingState ==
                                    ProcessingState.loading ||
                                state?.processingState ==
                                    ProcessingState.buffering;
                            final bool isPlaying = state?.playing ?? false;

                            if (isBuffering) {
                              return const SizedBox(
                                width: 64,
                                height: 64,
                                child: CircularProgressIndicator(),
                              );
                            }

                            return FilledButton(
                              onPressed: _audioService.playPause,
                              style: FilledButton.styleFrom(
                                shape: const CircleBorder(),
                                fixedSize: const Size(72, 72),
                                padding: EdgeInsets.zero,
                              ),
                              child: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 40,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          tooltip: '次の曲',
                          iconSize: 40,
                          onPressed: _audioService.seekToNext,
                          icon: const Icon(Icons.skip_next),
                        ),
                        const SizedBox(width: 8),
                        StreamBuilder<LoopMode>(
                          stream: _audioService.loopModeStream,
                          initialData: _audioService.loopMode,
                          builder: (context, snapshot) {
                            final LoopMode loopMode =
                                snapshot.data ?? LoopMode.off;
                            return IconButton(
                              tooltip: '繰り返し再生',
                              iconSize: 28,
                              color: loopMode == LoopMode.off
                                  ? null
                                  : colorScheme.primary,
                              onPressed: _audioService.cycleLoopMode,
                              icon: Icon(
                                loopMode == LoopMode.one
                                    ? Icons.repeat_one
                                    : Icons.repeat,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }
}
