import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/screens/playlist_edit_screen.dart';
import 'package:localyt_music/screens/song_player_screen.dart';
import 'package:localyt_music/services/audio_player_service.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/services/library_events.dart';
import 'package:localyt_music/services/yt_dl_service.dart';
import 'package:localyt_music/theme/app_palette.dart';
import 'package:localyt_music/utils/format.dart';
import 'package:localyt_music/widgets/app_buttons.dart';
import 'package:localyt_music/widgets/artwork.dart';
import 'package:localyt_music/widgets/marquee_text.dart';
import 'package:localyt_music/widgets/network_warning.dart';
import 'package:localyt_music/widgets/song_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SongSortOrder {
  title('タイトル順'),
  artist('アーティスト順'),
  newest('追加が新しい順'),
  oldest('追加が古い順');

  const SongSortOrder(this.label);

  final String label;
}

/// プレイリストの曲一覧。上部にジャケット・名前・シャッフル/再生/更新を置く。
class PlaylistScreen extends StatefulWidget {
  final String playlistName;
  const PlaylistScreen({super.key, required this.playlistName});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  // プレイリスト名がURLの保存キーとして使われているため、衝突しにくい接頭辞を付ける。
  static const String _kSongSortOrder = 'app_song_sort_order';

  /// 前に読んだ並び順。開くたびに保存値を待たずに並べるため。
  static SongSortOrder? _lastSortOrder;

  List<Song> _playlistSongs = [];
  SongSortOrder _sortOrder = _lastSortOrder ?? SongSortOrder.title;
  bool _isLoading = true;

  /// 読み込みが長引いたときだけ回転を出す(すぐ終わるときにちらつかせない)。
  bool _showSpinner = false;

  /// 曲の行を並べてよいか。開いた最初のフレームは見出しだけにして、
  /// 行を作る分を次のフレームへ回す(開くアニメーションの出だしを軽くする)。
  bool _rowsReady = false;
  bool _isUpdating = false;
  double _updateProgress = 0;

  @override
  void initState() {
    super.initState();
    // 前に開いたことがあれば、その曲一覧をすぐに出してから読み直す
    final List<Song>? cached = PlaylistManager.cachedSongs(widget.playlistName);
    if (cached != null && _lastSortOrder != null) {
      _playlistSongs = _sortSongs(cached, _sortOrder);
      _isLoading = false;
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isLoading) setState(() => _showSpinner = true);
      });
    }
    _loadSortOrderAndSongs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _rowsReady = true);
    });
  }

  Future<void> _loadSortOrderAndSongs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_kSongSortOrder);
    _sortOrder = _lastSortOrder = SongSortOrder.values.firstWhere(
      (order) => order.name == saved,
      orElse: () => SongSortOrder.title,
    );
    await _loadPlaylistSongs();
  }

  Future<void> _loadPlaylistSongs() async {
    PlaylistManager playlistManager = PlaylistManager(widget.playlistName);
    List<Song> playlistSongs = await playlistManager.getPlaylistSongs(
      widget.playlistName,
    );
    if (!mounted) return;
    final List<Song> sorted = _sortSongs(playlistSongs, _sortOrder);
    // 前に開いたときの一覧を出していて中身が変わっていなければ、作り直さない
    if (!_isLoading && _sameSongs(sorted, _playlistSongs)) return;
    setState(() {
      _playlistSongs = sorted;
      _isLoading = false;
    });
  }

  static bool _sameSongs(List<Song> a, List<Song> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final Song x = a[i];
      final Song y = b[i];
      if (x.path != y.path ||
          x.title != y.title ||
          x.artist != y.artist ||
          x.album != y.album ||
          x.thumbnailPath != y.thumbnailPath ||
          x.addedAt != y.addedAt) {
        return false;
      }
    }
    return true;
  }

  Future<void> _changeSortOrder(SongSortOrder order) async {
    if (order == _sortOrder) return;
    setState(() {
      _sortOrder = _lastSortOrder = order;
      _playlistSongs = _sortSongs(_playlistSongs, order);
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSongSortOrder, order.name);
  }

  static List<Song> _sortSongs(List<Song> songs, SongSortOrder order) {
    final DateTime unknown = DateTime.fromMillisecondsSinceEpoch(0);
    int byTitle(Song a, Song b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());
    int byAddedAt(Song a, Song b) =>
        (a.addedAt ?? unknown).compareTo(b.addedAt ?? unknown);
    // List.sort は安定ソートではないため、同値の場合はタイトルで順序を確定させる。
    int thenByTitle(int result, Song a, Song b) =>
        result != 0 ? result : byTitle(a, b);

    final List<Song> sorted = List<Song>.of(songs);
    switch (order) {
      case SongSortOrder.title:
        sorted.sort(byTitle);
      case SongSortOrder.artist:
        sorted.sort(
          (a, b) => thenByTitle(
            a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
            a,
            b,
          ),
        );
      case SongSortOrder.newest:
        sorted.sort((a, b) => thenByTitle(byAddedAt(b, a), a, b));
      case SongSortOrder.oldest:
        sorted.sort((a, b) => thenByTitle(byAddedAt(a, b), a, b));
    }
    return sorted;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _playInOrder() async {
    if (_playlistSongs.isEmpty) return;
    await SongPlayerScreen.open(context, _playlistSongs, 0, shuffle: false);
  }

  Future<void> _playShuffled() async {
    if (_playlistSongs.isEmpty) return;
    await SongPlayerScreen.open(
      context,
      _playlistSongs,
      Random().nextInt(_playlistSongs.length),
      shuffle: true,
    );
  }

  /// 保存済みURLから新しく増えた曲だけを取得する。
  Future<void> _updatePlaylist() async {
    if (_isUpdating) return;
    final String url = await PlaylistsManager().getPlayListURL(
      widget.playlistName,
    );
    if (!mounted) return;
    if (url.isEmpty) {
      _showSnackBar('プレイリストURLが保存されていません');
      return;
    }
    if (!await confirmProceedOnCurrentNetwork(context)) return;

    setState(() {
      _isUpdating = true;
      _updateProgress = 0;
    });
    final StreamSubscription<double> progressSubscription = YTDLService
        .progressStream
        .listen((progress) {
          if (!mounted || progress < 0) return;
          setState(() {
            _updateProgress = (progress / 100).clamp(0.0, 1.0);
          });
        });
    try {
      await YTDLService.startDownload(url, widget.playlistName, isUpdate: true);
      _showSnackBar('プレイリストを更新しました');
      LibraryEvents.instance.notifyChanged();
      await _loadPlaylistSongs();
    } catch (e) {
      _showSnackBar('更新に失敗しました: $e');
    } finally {
      await progressSubscription.cancel();
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _openEdit() async {
    final Object? result = await Navigator.of(context, rootNavigator: true)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                PlaylistEditScreen(playlistName: widget.playlistName),
          ),
        );
    if (!mounted) return;
    if (result == 'updated') {
      LibraryEvents.instance.notifyChanged();
      await _loadPlaylistSongs();
      return;
    }
    if (result == true) {
      // 名前の変更・削除でこのプレイリストは開けなくなる
      LibraryEvents.instance.notifyChanged();
      Navigator.pop(context, true);
    }
  }

  void _onMenuSelected(Object value) {
    if (value is SongSortOrder) {
      _changeSortOrder(value);
    } else if (value == 'edit') {
      _openEdit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final AudioPlayerService audioService = AudioPlayerService.instance;

    return Scaffold(
      backgroundColor: palette.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: padding.top)),
          SliverToBoxAdapter(child: _buildTopBar()),
          SliverToBoxAdapter(child: _buildHeader(palette)),
          if (!_rowsReady)
            const SliverToBoxAdapter()
          else if (_isLoading)
            SliverToBoxAdapter(
              child: _showSpinner
                  ? const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : null,
            )
          else if (_playlistSongs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(
                      Symbols.music_off_rounded,
                      size: 48,
                      color: palette.textFaint,
                    ),
                    const SizedBox(height: 12),
                    Text('曲がありません', style: TextStyle(color: palette.textMuted)),
                  ],
                ),
              ),
            )
          else
            StreamBuilder<int?>(
              stream: audioService.currentIndexStream,
              initialData: audioService.currentIndex,
              builder: (context, _) {
                final String? playingPath = audioService.currentSong?.path;
                // 行の高さは一定なので、測らずに並べて配置を軽くする
                return SliverFixedExtentList.builder(
                  itemExtent: SongRow.height,
                  itemCount: _playlistSongs.length,
                  itemBuilder: (context, index) {
                    final Song song = _playlistSongs[index];
                    return SongRow(
                      song: song,
                      playing: song.path == playingPath,
                      onTap: () =>
                          SongPlayerScreen.open(context, _playlistSongs, index),
                    );
                  },
                );
              },
            ),
          SliverToBoxAdapter(child: SizedBox(height: padding.bottom)),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: '戻る',
              icon: const Icon(Symbols.arrow_back_rounded),
              onPressed: () => Navigator.maybePop(context),
            ),
            const Spacer(),
            PopupMenuButton<Object>(
              tooltip: 'メニュー',
              icon: const Icon(Symbols.more_vert_rounded, size: 22),
              onSelected: _onMenuSelected,
              itemBuilder: (context) => [
                for (final SongSortOrder order in SongSortOrder.values)
                  CheckedPopupMenuItem<Object>(
                    value: order,
                    checked: order == _sortOrder,
                    child: Text(order.label),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem<Object>(
                  value: 'edit',
                  child: Text('プレイリストを編集'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette palette) {
    final DateTime? updatedAt = _playlistSongs
        .map((song) => song.addedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (latest, date) =>
              latest == null || date.isAfter(latest) ? date : latest,
        );
    final String meta = [
      '${_playlistSongs.length}曲',
      if (updatedAt != null) '${formatMonthDay(updatedAt)}に更新',
    ].join(' · ');
    final bool canPlay = !_isLoading && _playlistSongs.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        children: [
          Artwork(
            song: _playlistSongs.isEmpty ? null : _playlistSongs.first,
            height: 148,
            radius: palette.radiusCard,
            fallbackLabel: widget.playlistName,
          ),
          const SizedBox(height: 18),
          MarqueeText(
            widget.playlistName,
            textAlign: TextAlign.center,
            style: AppFonts.displayStyle(
              fontSize: 26,
              color: palette.text,
              letterSpacing: -0.26,
            ),
          ),
          const SizedBox(height: 8),
          Text(meta, style: AppFonts.monoStyle(color: palette.textMuted)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlineIconButton(
                icon: Symbols.shuffle_rounded,
                tooltip: 'シャッフル再生',
                onPressed: canPlay ? _playShuffled : null,
              ),
              const SizedBox(width: 16),
              PlayButton(
                icon: Symbols.play_arrow_rounded,
                tooltip: '再生',
                size: 64,
                iconSize: 36,
                onPressed: canPlay ? _playInOrder : null,
              ),
              const SizedBox(width: 16),
              OutlineIconButton(
                icon: Symbols.sync_rounded,
                tooltip: _isUpdating ? '更新中' : '新しい曲を取得',
                onPressed: _isUpdating ? null : _updatePlaylist,
                child: _isUpdating
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          value: _updateProgress > 0 ? _updateProgress : null,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
