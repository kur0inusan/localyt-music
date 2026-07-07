import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:localyt_music/models/playlist.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/screens/add_playlist_screen.dart';
import 'package:localyt_music/screens/playlist_screen.dart';
import 'package:localyt_music/screens/song_player_screen.dart';
import 'package:localyt_music/services/audio_player_service.dart';
import 'package:localyt_music/services/file_service.dart';
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

/// 再生中の曲を大きめのカードで表示する。何も再生していなければ非表示。
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
          return const SizedBox.shrink();
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
