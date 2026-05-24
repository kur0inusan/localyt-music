import 'package:flutter/material.dart';

class AddPlaylistScreen extends StatefulWidget {
  const AddPlaylistScreen({super.key});
  @override
  State<AddPlaylistScreen> createState() => _AddPlaylistScreenState();
}

class _AddPlaylistScreenState extends State<AddPlaylistScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Playlist'),
      ),
      body: Column(
        children: [

        ],
      )
    );
  }
}
