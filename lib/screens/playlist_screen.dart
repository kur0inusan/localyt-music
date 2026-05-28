import 'package:flutter/material.dart';
import 'package:localyt_music/services/file_service.dart';

class PlaylistScreen extends StatefulWidget {
  final _playlistname;
  const PlaylistScreen({super.key, required playlistname}) : _playlistname = playlistname;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<String> _playlistSongs = [];

  @override
  void initState(){
    super.initState();
    _loadPlaylistSongs();
  }

  void _loadPlaylistSongs() async {
    PlaylistManager playlistManager = PlaylistManager(widget._playlistname);
    List<String> playlistSongs = await playlistManager.getPlaylistSongs(widget._playlistname);
    setState(() {
      _playlistSongs = playlistSongs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('${widget._playlistname}'),
        ),
        body: Column(
          children: <Widget>[
            for (String songName in _playlistSongs)
              ListTile(
                title: Text(songName),
              )
          ],
        ),
    );
  }
}
