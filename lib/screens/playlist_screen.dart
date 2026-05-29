import 'package:flutter/material.dart';
import 'package:localyt_music/screens/playlist_edit_screen.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/models/song.dart';

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
      body: Column(
        children: <Widget>[
          for (Song songName in _playlistSongs)
            ListTile(
              title: Text(
                songName.title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              subtitle: Text(
                '${songName.artist} - ${songName.albam}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }
}
