import 'package:flutter/material.dart';
import 'package:localyt_music/models/playlist.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/screens/playlist_screen.dart';
import 'package:localyt_music/screens/add_playlist_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});
  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final PlaylistsManager _playlistManager = PlaylistsManager();
  List<Playlist> _playlists = [];
  void _loadPlaylists() async {
    List<Playlist> playlists = await _playlistManager.getAllPlaylist();
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          for (Playlist playlist in _playlists)
            ListTile(
              title: Text(playlist.name),
              subtitle: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(text: '${playlist.songs}曲'),
                    ]
                ),
              ),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PlaylistScreen(playlistName: playlist.name),
                  ),
                );
                if (result == true) {
                  _loadPlaylists();
                }
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // 追加ボタン
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPlaylistScreen()),
          );
          if (result == true) {
            _loadPlaylists();
          }
        },
      ),
    );
  }
}
