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
  bool _isSavingOrder = false;

  void _loadPlaylists() async {
    List<Playlist> playlists = await _playlistManager.getAllPlaylist();
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
    });
  }

  Future<void> _reorderPlaylists(int oldIndex, int newIndex) async {
    if (_isSavingOrder || oldIndex == newIndex) return;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final List<Playlist> previousOrder = List<Playlist>.of(_playlists);
    setState(() {
      final Playlist movedPlaylist = _playlists.removeAt(oldIndex);
      _playlists.insert(newIndex, movedPlaylist);
      _isSavingOrder = true;
    });

    try {
      await _playlistManager.savePlaylistOrder(
        _playlists.map((playlist) => playlist.name).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _playlists = previousOrder;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('並べ替えの保存に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingOrder = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.queue_music,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'プレイリストがありません',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '右下の + ボタンから追加できます',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              buildDefaultDragHandles: false,
              onReorder: _reorderPlaylists,
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                final Playlist playlist = _playlists[index];
                return Card(
                  key: ValueKey(playlist.name),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      child: const Icon(Icons.queue_music),
                    ),
                    title: Text(
                      playlist.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${playlist.songs}曲'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chevron_right),
                        const SizedBox(width: 4),
                        if (_isSavingOrder)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          ReorderableDragStartListener(
                            index: index,
                            child: const Tooltip(
                              message: 'ドラッグして並べ替え',
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                      ],
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
                );
              },
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
