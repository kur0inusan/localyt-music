import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:localyt_music/models/playlist.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/screens/add_playlist_screen.dart';
import 'package:localyt_music/screens/playlist_screen.dart';
import 'package:localyt_music/screens/setting_screen.dart';
import 'package:localyt_music/screens/song_player_screen.dart';
import 'package:localyt_music/services/audio_player_service.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/services/library_events.dart';
import 'package:localyt_music/services/play_history_service.dart';
import 'package:localyt_music/theme/app_palette.dart';
import 'package:localyt_music/utils/display_title.dart';
import 'package:localyt_music/utils/format.dart';
import 'package:localyt_music/widgets/app_buttons.dart';
import 'package:localyt_music/widgets/artwork.dart';
import 'package:localyt_music/widgets/song_row.dart';

/// ホーム画面。「聴く」ための入口で、続きから・おすすめ・よく聴く曲・
/// 最近再生した曲・プレイリストの棚を並べる。プレイリストの管理はライブラリで行う。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Playlist> _playlists = [];

  /// おすすめの候補にする全プレイリストの曲。
  List<Song> _library = [];

  /// 棚に出すプレイリストごとの代表曲(サムネイル用)。
  Map<String, Song> _covers = {};
  bool _isLoading = true;

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
    _playlists = playlists;
    _library = [for (final List<Song> songs in songsPerPlaylist) ...songs];
    _covers = {
      for (int i = 0; i < playlists.length; i++)
        if (songsPerPlaylist[i].isNotEmpty)
          playlists[i].name: songsPerPlaylist[i].first,
    };
    _isLoading = false;
  }

  void _openSettings() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (context) => const SettingScreen()));
  }

  Future<void> _openAddPlaylist() async {
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (context) => const AddPlaylistScreen()));
  }

  Future<void> _openPlaylist(Playlist playlist) async {
    await Navigator.push(
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPlaylists,
              edgeOffset: padding.top,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: padding.top,
                  bottom: padding.bottom,
                ),
                children: [
                  _HomeHeader(onSettings: _openSettings),
                  const _NowPlayingCard(),
                  _PlayHistorySections(library: _library),
                  _PlaylistShelf(
                    playlists: _playlists,
                    covers: _covers,
                    onOpen: _openPlaylist,
                    onAdd: _openAddPlaylist,
                  ),
                ],
              ),
            ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'LocalYT',
                style: AppFonts.displayStyle(
                  fontSize: 20,
                  color: palette.text,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            IconButton(
              tooltip: '設定',
              icon: const Icon(Symbols.settings_rounded),
              onPressed: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// 再生中の曲を表示する。何も読み込まれていなければ前回の続きから再生する
/// カードを、それも無ければ何も表示しない。
class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard();

  @override
  Widget build(BuildContext context) {
    final AudioPlayerService audioService = AudioPlayerService.instance;
    return StreamBuilder<int?>(
      stream: audioService.currentIndexStream,
      initialData: audioService.currentIndex,
      builder: (context, _) {
        final Song? song = audioService.currentSong;
        if (song == null) return const _ResumeCard();

        return StreamBuilder<PlayerState>(
          stream: audioService.playerStateStream,
          initialData: audioService.player.playerState,
          builder: (context, stateSnapshot) {
            final bool isPlaying = stateSnapshot.data?.playing ?? false;
            return _PlaybackCard(
              song: song,
              label: Text(isPlaying ? '再生中' : '一時停止中'),
              buttonIcon: isPlaying
                  ? Symbols.pause_rounded
                  : Symbols.play_arrow_rounded,
              buttonTooltip: isPlaying ? '一時停止' : '再生',
              onButton: audioService.playPause,
              onTap: () => SongPlayerScreen.openCurrent(context),
            );
          },
        );
      },
    );
  }
}

/// アプリ起動直後など何も読み込まれていないときに、前回の続きから再生するカード。
class _ResumeCard extends StatefulWidget {
  const _ResumeCard();

  @override
  State<_ResumeCard> createState() => _ResumeCardState();
}

class _ResumeCardState extends State<_ResumeCard> {
  bool _isResuming = false;

  Future<void> _resume() async {
    if (_isResuming) return;
    setState(() {
      _isResuming = true;
    });
    bool resumed = false;
    try {
      resumed = await AudioPlayerService.instance.resumeLastSession();
    } catch (_) {
      resumed = false;
    }
    // 復元に成功すると再生中カードに置き換わり、このWidgetは破棄される。
    if (!mounted) return;
    setState(() {
      _isResuming = false;
    });
    if (!resumed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('前回の曲が見つかりませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 設定画面で履歴を削除したときにカードを消す
    return ListenableBuilder(
      listenable: PlayHistoryService.instance,
      builder: (context, _) => _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final ResumePoint? point = PlayHistoryService.instance.resumePoint;
    if (point == null || !File(point.song.path).existsSync()) {
      return const SizedBox.shrink();
    }
    final AppPalette palette = AppPalette.of(context);
    return _PlaybackCard(
      song: point.song,
      label: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: '続きから · '),
            TextSpan(
              text: formatPlaybackTime(point.position),
              style: AppFonts.monoStyle(fontSize: 11, color: palette.accent),
            ),
          ],
        ),
      ),
      buttonIcon: Symbols.play_arrow_rounded,
      buttonTooltip: '続きから再生',
      busy: _isResuming,
      onButton: _resume,
      onTap: _resume,
    );
  }
}

/// 「続きから」「再生中」の面。ホームで面を持つのはこのカードだけ。
class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({
    required this.song,
    required this.label,
    required this.buttonIcon,
    required this.buttonTooltip,
    required this.onButton,
    required this.onTap,
    this.busy = false,
  });

  final Song song;
  final Widget label;
  final IconData buttonIcon;
  final String buttonTooltip;
  final VoidCallback onButton;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final BorderRadius radius = BorderRadius.circular(palette.radiusCard);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: radius,
          boxShadow: palette.raisedShadows,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 76,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Artwork(song: song, height: 56, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DefaultTextStyle.merge(
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.accent,
                            ),
                            child: label,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayTitle(song),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.displayStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    busy
                        ? const SizedBox(
                            width: 56,
                            height: 56,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : PlayButton(
                            icon: buttonIcon,
                            tooltip: buttonTooltip,
                            onPressed: onButton,
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _FrequentPeriod { recent, allTime }

/// おすすめ・よく聴く曲・最近再生した曲。曲をタップすると、
/// そのセクションの曲順で再生する。
class _PlayHistorySections extends StatefulWidget {
  const _PlayHistorySections({required this.library});

  /// おすすめの候補にする全プレイリストの曲。
  final List<Song> library;

  @override
  State<_PlayHistorySections> createState() => _PlayHistorySectionsState();
}

class _PlayHistorySectionsState extends State<_PlayHistorySections> {
  static const int _recommendGridCount = 4;

  _FrequentPeriod _period = _FrequentPeriod.recent;

  @override
  Widget build(BuildContext context) {
    final PlayHistoryService history = PlayHistoryService.instance;
    final AppPalette palette = AppPalette.of(context);

    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final List<Recommendation> recommendations = history.recommend(
          widget.library,
        );
        final List<Song> recommendedSongs = [
          for (final Recommendation recommendation in recommendations)
            recommendation.song,
        ];
        final List<({Song song, int count})> recentFrequent = history
            .recentFrequentSongs();
        final List<({Song song, int count})> allTime = history.frequentSongs();
        // 2週間の分が無ければ全期間を出す
        final _FrequentPeriod period = recentFrequent.isEmpty
            ? _FrequentPeriod.allTime
            : _period;
        final List<({Song song, int count})> frequent =
            period == _FrequentPeriod.recent ? recentFrequent : allTime;
        final List<Song> frequentSongs = [
          for (final entry in frequent) entry.song,
        ];
        final List<Song> recent = history.recentSongs();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (recommendations.isNotEmpty) ...[
              SectionHeader(
                title: 'おすすめ',
                trailing: ChipButton(
                  label: 'すべて再生',
                  onPressed: () =>
                      SongPlayerScreen.open(context, recommendedSongs, 0),
                ),
              ),
              _RecommendationGrid(
                songs: recommendedSongs.take(_recommendGridCount).toList(),
                onTap: (index) =>
                    SongPlayerScreen.open(context, recommendedSongs, index),
              ),
            ],
            if (frequent.isNotEmpty) ...[
              SectionHeader(
                title: 'よく聴く曲',
                padding: const EdgeInsets.fromLTRB(20, 36, 20, 6),
                trailing: recentFrequent.isEmpty
                    ? null
                    : _PeriodToggle(
                        value: period,
                        onChanged: (value) => setState(() {
                          _period = value;
                        }),
                      ),
              ),
              for (int i = 0; i < frequent.length; i++)
                SongRow(
                  song: frequent[i].song,
                  onTap: () => SongPlayerScreen.open(context, frequentSongs, i),
                  trailing: Text(
                    '${frequent[i].count}回',
                    style: AppFonts.monoStyle(color: palette.textMuted),
                  ),
                ),
            ],
            if (recent.isNotEmpty) ...[
              const SectionHeader(
                title: '最近再生した曲',
                padding: EdgeInsets.fromLTRB(20, 28, 20, 14),
              ),
              SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: recent.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: 120,
                    child: _SongCard(
                      song: recent[index],
                      artHeight: 120,
                      onTap: () =>
                          SongPlayerScreen.open(context, recent, index),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// おすすめの2列グリッド。カードは面を持たず、サムネイルの下に曲名を置く。
class _RecommendationGrid extends StatelessWidget {
  const _RecommendationGrid({required this.songs, required this.onTap});

  final List<Song> songs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final double cardWidth = (MediaQuery.sizeOf(context).width - 40 - 12) / 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          for (int i = 0; i < songs.length; i++)
            SizedBox(
              width: cardWidth,
              child: _SongCard(
                song: songs[i],
                artHeight: 150,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({
    required this.song,
    required this.artHeight,
    required this.onTap,
  });

  final Song song;
  final double artHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(palette.radiusArtLarge),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Artwork(
            song: song,
            height: artHeight,
            width: double.infinity,
            radius: palette.radiusArtLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              displayTitle(song),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, height: 1.45, color: palette.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「よく聴く曲」の期間切り替え。小さなカプセルのセグメント。
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});

  final _FrequentPeriod value;
  final ValueChanged<_FrequentPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    Widget segment(_FrequentPeriod period, String label) {
      final bool selected = period == value;
      return GestureDetector(
        onTap: () => onChanged(period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: selected ? palette.surface : Colors.transparent,
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              color: selected ? palette.accent : palette.textMuted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: palette.border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(_FrequentPeriod.recent, '2週間'),
          segment(_FrequentPeriod.allTime, '全期間'),
        ],
      ),
    );
  }
}

/// プレイリストの棚。管理(並べ替え・追加・削除)はライブラリで行い、
/// ここは開くための入口だけ。
class _PlaylistShelf extends StatelessWidget {
  const _PlaylistShelf({
    required this.playlists,
    required this.covers,
    required this.onOpen,
    required this.onAdd,
  });

  final List<Playlist> playlists;
  final Map<String, Song> covers;
  final ValueChanged<Playlist> onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    if (playlists.isEmpty) {
      return _EmptyLibrary(onAdd: onAdd);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'プレイリスト',
          padding: EdgeInsets.fromLTRB(20, 34, 20, 14),
        ),
        SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: playlists.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final Playlist playlist = playlists[index];
              return SizedBox(
                width: 140,
                child: InkWell(
                  borderRadius: BorderRadius.circular(palette.radiusArtLarge),
                  onTap: () => onOpen(playlist),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Artwork(
                        song: covers[playlist.name],
                        height: 140,
                        radius: palette.radiusArtLarge,
                        fallbackLabel: playlist.name,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.displayStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '${playlist.songs}曲',
                          style: AppFonts.monoStyle(color: palette.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
      child: Column(
        children: [
          Icon(
            Symbols.library_music_rounded,
            size: 48,
            color: palette.textFaint,
          ),
          const SizedBox(height: 16),
          Text(
            'プレイリストがまだありません',
            style: AppFonts.displayStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'YouTubeのプレイリストをダウンロードして\nオフラインで聴けます',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Symbols.add_rounded),
            label: const Text('プレイリストを追加'),
          ),
        ],
      ),
    );
  }
}
