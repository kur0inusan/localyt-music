import 'package:flutter/material.dart';
import 'package:localyt_music/screens/playlist_edit_screen.dart';
import 'package:localyt_music/screens/song_player_screen.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/widgets/mini_player.dart';

class PlaylistScreen extends StatefulWidget {
  final String playlistName;
  const PlaylistScreen({super.key, required this.playlistName});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<Song> _playlistSongs = [];

  @override
  void initState() {
    super.initState();
    _loadPlaylistSongs();
  }

  void _loadPlaylistSongs() async {
    PlaylistManager playlistManager = PlaylistManager(widget.playlistName);
    List<Song> playlistSongs = await playlistManager.getPlaylistSongs(
      widget.playlistName,
    );
    if (!mounted) return;
    setState(() {
      _playlistSongs = playlistSongs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistName),
        actions: <Widget>[
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
          ? const Center(child: Text('曲がありません'))
          : ListView.builder(
              itemCount: _playlistSongs.length,
              itemBuilder: (context, index) {
                final Song song = _playlistSongs[index];
                return ListTile(
                  // leading: const Icon(Icons.music_note),
                  title: Text(
                    song.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  subtitle: Text(
                    [
                      song.artist,
                      song.album,
                    ].where((value) => value.isNotEmpty).join(' - '),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  trailing: const Icon(Icons.play_arrow),
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
