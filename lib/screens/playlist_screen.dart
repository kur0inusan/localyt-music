import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:localyt_music/screens/playlist_edit_screen.dart';
import 'package:localyt_music/screens/song_player_screen.dart';
import 'package:localyt_music/services/audio_player_service.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/widgets/mini_player.dart';
import 'package:localyt_music/widgets/song_thumbnail.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SongSortOrder {
  title('タイトル順'),
  artist('アーティスト順'),
  newest('追加が新しい順'),
  oldest('追加が古い順');

  const SongSortOrder(this.label);

  final String label;
}

class PlaylistScreen extends StatefulWidget {
  final String playlistName;
  const PlaylistScreen({super.key, required this.playlistName});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  // プレイリスト名がURLの保存キーとして使われているため、衝突しにくい接頭辞を付ける。
  static const String _kSongSortOrder = 'app_song_sort_order';

  List<Song> _playlistSongs = [];
  SongSortOrder _sortOrder = SongSortOrder.title;

  @override
  void initState() {
    super.initState();
    _loadSortOrderAndSongs();
  }

  Future<void> _loadSortOrderAndSongs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_kSongSortOrder);
    _sortOrder = SongSortOrder.values.firstWhere(
      (order) => order.name == saved,
      orElse: () => SongSortOrder.title,
    );
    _loadPlaylistSongs();
  }

  void _loadPlaylistSongs() async {
    PlaylistManager playlistManager = PlaylistManager(widget.playlistName);
    List<Song> playlistSongs = await playlistManager.getPlaylistSongs(
      widget.playlistName,
    );
    if (!mounted) return;
    setState(() {
      _playlistSongs = _sortSongs(playlistSongs, _sortOrder);
    });
  }

  Future<void> _changeSortOrder(SongSortOrder order) async {
    if (order == _sortOrder) return;
    setState(() {
      _sortOrder = order;
      _playlistSongs = _sortSongs(_playlistSongs, order);
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSongSortOrder, order.name);
  }

  static List<Song> _sortSongs(List<Song> songs, SongSortOrder order) {
    final DateTime unknown = DateTime.fromMillisecondsSinceEpoch(0);
    int byTitle(Song a, Song b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());
    int byAddedAt(Song a, Song b) =>
        (a.addedAt ?? unknown).compareTo(b.addedAt ?? unknown);
    // List.sort は安定ソートではないため、同値の場合はタイトルで順序を確定させる。
    int thenByTitle(int result, Song a, Song b) =>
        result != 0 ? result : byTitle(a, b);

    final List<Song> sorted = List<Song>.of(songs);
    switch (order) {
      case SongSortOrder.title:
        sorted.sort(byTitle);
      case SongSortOrder.artist:
        sorted.sort(
          (a, b) => thenByTitle(
            a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
            a,
            b,
          ),
        );
      case SongSortOrder.newest:
        sorted.sort((a, b) => thenByTitle(byAddedAt(b, a), a, b));
      case SongSortOrder.oldest:
        sorted.sort((a, b) => thenByTitle(byAddedAt(a, b), a, b));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final AudioPlayerService audioService = AudioPlayerService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistName),
        actions: <Widget>[
          PopupMenuButton<SongSortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: '並べ替え',
            initialValue: _sortOrder,
            onSelected: _changeSortOrder,
            itemBuilder: (context) => [
              for (final SongSortOrder order in SongSortOrder.values)
                CheckedPopupMenuItem<SongSortOrder>(
                  value: order,
                  checked: order == _sortOrder,
                  child: Text(order.label),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PlaylistEditScreen(playlistName: widget.playlistName),
                ),
              );
              if (!context.mounted) return;
              if (result == 'updated') {
                _loadPlaylistSongs();
                return;
              }
              if (result == true) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: _playlistSongs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.music_off,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '曲がありません',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _playlistSongs.length,
              itemBuilder: (context, index) {
                final Song song = _playlistSongs[index];
                return StreamBuilder<int?>(
                  stream: audioService.currentIndexStream,
                  initialData: audioService.currentIndex,
                  builder: (context, indexSnapshot) {
                    final int? currentIndex = indexSnapshot.data;
                    final bool isCurrentSong =
                        currentIndex != null &&
                        currentIndex >= 0 &&
                        currentIndex < audioService.songs.length &&
                        audioService.songs[currentIndex].path == song.path;

                    return ListTile(
                      tileColor: isCurrentSong
                          ? colorScheme.primaryContainer.withValues(
                              alpha: 0.3,
                            )
                          : null,
                      leading: SongThumbnail(song: song),
                      title: Text(
                        song.title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: isCurrentSong
                            ? TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              )
                            : null,
                      ),
                      subtitle: Text(
                        [
                          song.artist,
                          song.album,
                        ].where((value) => value.isNotEmpty).join(' - '),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      trailing: !isCurrentSong
                          ? const Icon(Icons.play_arrow)
                          : StreamBuilder<PlayerState>(
                              stream: audioService.playerStateStream,
                              initialData: audioService.player.playerState,
                              builder: (context, stateSnapshot) {
                                final bool isPlaying =
                                    stateSnapshot.data?.playing ?? false;
                                return Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: colorScheme.primary,
                                );
                              },
                            ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SongPlayerScreen(
                              songs: _playlistSongs,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: Material(
        color: colorScheme.surfaceContainerHigh,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MiniPlayer(),
            SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
