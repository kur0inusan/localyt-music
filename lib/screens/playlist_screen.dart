import 'package:flutter/material.dart';
import 'package:localyt_music/screens/playlist_edit_screen.dart';
import 'package:localyt_music/services/file_service.dart';

class PlaylistScreen extends StatefulWidget {
  final String playlistName;
  const PlaylistScreen({super.key, required this.playlistName});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<String> _playlistSongs = [];

  @override
  void initState() {
    super.initState();
    _loadPlaylistSongs();
  }

  void _loadPlaylistSongs() async {
    PlaylistManager playlistManager = PlaylistManager(widget.playlistName);
    List<String> playlistSongs = await playlistManager.getPlaylistSongs(
      widget.playlistName,
    );
    if (!mounted) return;
    setState(() {
      _playlistSongs = playlistSongs;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              if (result == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          for (String songName in _playlistSongs)
            ListTile(title: Text(songName)),
        ],
      ),
    );
  }
}
