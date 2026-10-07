import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:localyt_music/models/playlist.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/screens/add_playlist_screen.dart';
import 'package:localyt_music/screens/playlist_screen.dart';
import 'package:localyt_music/screens/song_player_screen.dart';
import 'package:localyt_music/services/audio_player_service.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/services/play_history_service.dart';
import 'package:localyt_music/widgets/song_thumbnail.dart';

/// ホーム画面。再生中の曲と保存済みプレイリストへのクイックアクセスを表示する。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PlaylistsManager _playlistsManager = PlaylistsManager();
  List<Playlist> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final List<Playlist> playlists = await _playlistsManager.getAllPlaylist();
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
      _isLoading = false;
    });
  }

  Future<void> _openPlaylist(Playlist playlist) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistScreen(playlistName: playlist.name),
      ),
    );
    _loadPlaylists();
  }

  Future<void> _openAddPlaylist() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPlaylistScreen()),
    );
    _loadPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadPlaylists,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _NowPlayingCard(),
          const _PlayHistorySections(),
          _SectionTitle(
            title: 'プレイリスト',
            trailing: TextButton.icon(
              onPressed: _openAddPlaylist,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('追加'),
            ),
          ),
          const SizedBox(height: 4),
          if (_playlists.isEmpty)
            _EmptyPlaylists(onAdd: _openAddPlaylist)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.9,
              ),
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                final Playlist playlist = _playlists[index];
                return _PlaylistTile(
                  playlist: playlist,
                  onTap: () => _openPlaylist(playlist),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// 再生中の曲を大きめのカードで表示する。何も読み込まれていなければ
/// 前回の続きから再生するカードを、それも無ければ何も表示しない。
class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard();

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
          return const _ResumeCard();
        }
        final Song song = songs[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(title: '再生中'),
            const SizedBox(height: 4),
            Card(
              color: colorScheme.primaryContainer,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SongPlayerScreen(
                        songs: songs,
                        initialIndex: index,
                        autoPlay: false,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SongThumbnail(song: song, size: 64, borderRadius: 8),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            if (song.artist.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      StreamBuilder<PlayerState>(
                        stream: audioService.playerStateStream,
                        initialData: audioService.player.playerState,
                        builder: (context, stateSnapshot) {
                          final bool isPlaying =
                              stateSnapshot.data?.playing ?? false;
                          return IconButton.filled(
                            onPressed: audioService.playPause,
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

/// アプリ起動直後など何も読み込まれていないときに、前回の続きから再生するカード。
class _ResumeCard extends StatefulWidget {
  const _ResumeCard();

  @override
  State<_ResumeCard> createState() => _ResumeCardState();
}

class _ResumeCardState extends State<_ResumeCard> {
  bool _isResuming = false;

  Future<void> _resume() async {
    if (_isResuming) return;
    setState(() {
      _isResuming = true;
    });
    bool resumed = false;
    try {
      resumed = await AudioPlayerService.instance.resumeLastSession();
    } catch (_) {
      resumed = false;
    }
    // 復元に成功すると再生中カードに置き換わり、このWidgetは破棄される。
    if (!mounted) return;
    setState(() {
      _isResuming = false;
    });
    if (!resumed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('前回の曲が見つかりませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ResumePoint? point = PlayHistoryService.instance.resumePoint;
    if (point == null || !File(point.song.path).existsSync()) {
      return const SizedBox.shrink();
    }
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(title: '続きから再生'),
        const SizedBox(height: 4),
        Card(
          color: colorScheme.secondaryContainer,
          child: InkWell(
            onTap: _resume,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SongThumbnail(song: point.song, size: 64, borderRadius: 8),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (point.song.artist.isNotEmpty) point.song.artist,
                            '${_formatPosition(point.position)} から',
                          ].join(' ・ '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSecondaryContainer.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isResuming)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton.filled(
                      onPressed: _resume,
                      icon: const Icon(Icons.play_arrow),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  static String _formatPosition(Duration position) {
    final int hours = position.inHours;
    final String minutes = position.inMinutes
        .remainder(60)
        .toString()
        .padLeft(hours > 0 ? 2 : 1, '0');
    final String seconds = position.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

/// 最近再生した曲とよく聴く曲。タップするとそのセクションの曲順で再生する。
class _PlayHistorySections extends StatelessWidget {
  const _PlayHistorySections();

  void _play(BuildContext context, List<Song> songs, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SongPlayerScreen(songs: songs, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlayHistoryService history = PlayHistoryService.instance;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final List<Song> recent = history.recentSongs();
        final List<({Song song, int count})> frequent = history
            .frequentSongs();
        final List<Song> frequentSongs = [
          for (final entry in frequent) entry.song,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (recent.isNotEmpty) ...[
              const _SectionTitle(title: '最近再生した曲'),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recent.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final Song song = recent[index];
                    return SizedBox(
                      width: 112,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _play(context, recent, index),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SongThumbnail(
                              song: song,
                              size: 112,
                              borderRadius: 8,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (song.artist.isNotEmpty)
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (frequent.isNotEmpty) ...[
              const _SectionTitle(title: 'よく聴く曲'),
              const SizedBox(height: 4),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (int i = 0; i < frequent.length; i++)
                      ListTile(
                        leading: SongThumbnail(song: frequent[i].song),
                        title: Text(
                          frequent[i].song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: frequent[i].song.artist.isEmpty
                            ? null
                            : Text(
                                frequent[i].song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: Text(
                          '${frequent[i].count}回',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () => _play(context, frequentSongs, i),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        ?trailing,
      ],
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist, required this.onTap});

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: const Icon(Icons.queue_music, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${playlist.songs}曲',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPlaylists extends StatelessWidget {
  const _EmptyPlaylists({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'プレイリストがまだありません',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'YouTubeのプレイリストをダウンロードして\nオフラインで楽しめます',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('プレイリストを追加'),
            ),
          ],
        ),
      ),
    );
  }
}
