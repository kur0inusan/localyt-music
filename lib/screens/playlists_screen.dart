import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:localyt_music/models/playlist.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/services/library_events.dart';
import 'package:localyt_music/screens/playlist_screen.dart';
import 'package:localyt_music/screens/add_playlist_screen.dart';
import 'package:localyt_music/theme/app_palette.dart';
import 'package:localyt_music/widgets/artwork.dart';

/// ライブラリ。プレイリストの一覧・並べ替え・追加を行う。
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});
  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final PlaylistsManager _playlistManager = PlaylistsManager();
  List<Playlist> _playlists = [];

  /// プレイリストごとの代表曲(サムネイル用)。
  Map<String, Song> _covers = {};
  bool _isLoading = true;
  bool _isSavingOrder = false;

  @override
  void initState() {
    super.initState();
    LibraryEvents.instance.addListener(_loadPlaylists);
    final LibrarySnapshot? latest = LibrarySnapshot.latest;
    if (latest != null) _apply(latest);
    _loadPlaylists();
  }

  @override
  void dispose() {
    LibraryEvents.instance.removeListener(_loadPlaylists);
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    final LibrarySnapshot snapshot = await LibrarySnapshot.load();
    if (!mounted) return;
    setState(() => _apply(snapshot));
  }

  void _apply(LibrarySnapshot snapshot) {
    final List<Playlist> playlists = snapshot.playlists;
    final List<List<Song>> songsPerPlaylist = snapshot.songsPerPlaylist;
    // 並べ替えで書き換えるため、共有しているリストを複製する
    _playlists = List<Playlist>.of(playlists);
    _covers = {
      for (int i = 0; i < playlists.length; i++)
        if (songsPerPlaylist[i].isNotEmpty)
          playlists[i].name: songsPerPlaylist[i].first,
    };
    _isLoading = false;
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
      LibraryEvents.instance.notifyChanged();
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

  void _openAddPlaylist() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (context) => const AddPlaylistScreen()));
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistScreen(playlistName: playlist.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: palette.bg,
      body: Column(
        children: [
          SizedBox(height: padding.top),
          SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'ライブラリ',
                      style: AppFonts.displayStyle(
                        fontSize: 20,
                        color: palette.text,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'プレイリストを追加',
                    icon: const Icon(Symbols.add_rounded),
                    onPressed: _openAddPlaylist,
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody(palette, padding)),
        ],
      ),
    );
  }

  Widget _buildBody(AppPalette palette, EdgeInsets padding) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.library_music_rounded,
                size: 48,
                color: palette.textFaint,
              ),
              const SizedBox(height: 16),
              Text(
                'プレイリストがありません',
                style: AppFonts.displayStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _openAddPlaylist,
                icon: const Icon(Symbols.add_rounded),
                label: const Text('プレイリストを追加'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlaylists,
      child: ReorderableListView.builder(
        padding: EdgeInsets.only(top: 4, bottom: padding.bottom),
        buildDefaultDragHandles: false,
        onReorder: _reorderPlaylists,
        proxyDecorator: (child, index, animation) => Material(
          color: palette.surface,
          borderRadius: BorderRadius.circular(palette.radiusArtLarge),
          child: child,
        ),
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final Playlist playlist = _playlists[index];
          return InkWell(
            key: ValueKey(playlist.name),
            onTap: () => _openPlaylist(playlist),
            child: SizedBox(
              height: 76,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 8),
                child: Row(
                  children: [
                    Artwork(
                      song: _covers[playlist.name],
                      height: 56,
                      radius: palette.radiusArtSmall,
                      fallbackLabel: playlist.name,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.displayStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${playlist.songs}曲',
                            style: AppFonts.monoStyle(color: palette.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (_isSavingOrder)
                      const SizedBox(
                        width: 44,
                        height: 44,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      ReorderableDragStartListener(
                        index: index,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Tooltip(
                            message: 'ドラッグして並べ替え',
                            child: Icon(
                              Symbols.drag_indicator_rounded,
                              color: palette.textFaint,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
