import 'package:flutter/material.dart';

class PlaylistScreen extends StatefulWidget {
  final _playlistname;
  const PlaylistScreen({super.key, required playlistname}) : _playlistname = playlistname;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('${widget._playlistname}'),
        ),
        body: Column(
          children: <Widget>[
            Placeholder()
          ],
        ),
    );
  }
}
