import 'package:flutter/material.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/screens/playlist_screen.dart';
import 'package:localyt_music/screens/add_playlist_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({Key? key}) : super(key: key);
  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}
class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final PlaylistManager _playlistManager = PlaylistManager();
  List<String> _playlistNames = [];
  void _loadPlaylists() async {
    List<String> playlistNames = await _playlistManager.getAllPlaylistName();
    setState(() {
      _playlistNames = playlistNames;
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
          for (String playlistName in _playlistNames)
            ListTile(
              title: Text(playlistName),
              onTap: (){
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PlaylistScreen(playlistname: playlistName)),
                );
              },
            )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // 追加ボタン
        child: const Icon(Icons.add),
        onPressed: (){
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddPlaylistScreen()),
          );
        },
      ),
    );
  }
}