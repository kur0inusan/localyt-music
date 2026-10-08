import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:localyt_music/screens/home_screen.dart';
import 'package:localyt_music/screens/playlists_screen.dart';
import 'package:localyt_music/services/audio_player_service.dart';
import 'package:localyt_music/theme/app_palette.dart';
import 'package:localyt_music/theme/app_theme.dart';
import 'package:localyt_music/widgets/floating_nav_bar.dart';
import 'package:localyt_music/widgets/mini_player.dart';
import 'package:localyt_music/widgets/storage_permission_dialog.dart';

/// 下タブ(ホーム / ライブラリ)とミニプレイヤーを画面の上に浮かべる骨組み。
///
/// タブごとに画面の積み重ねを持つので、プレイリスト詳細を開いても
/// 下タブとミニプレイヤーは残る。プレイヤー・設定・追加・編集はタブの外
/// (ルートの Navigator)に全画面で開く。タブは左右に払っても切り替わる。
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const double _navBottomGap = 18;
  static const double _miniGap = 10;

  static const List<FloatingNavItem> _navItems = [
    FloatingNavItem(icon: Symbols.home_rounded, label: 'ホーム'),
    FloatingNavItem(icon: Symbols.library_music_rounded, label: 'ライブラリ'),
  ];

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// タブを切り替える。下タブの印はすぐ動かし、画面は横に流して見せる。
  void _showTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    // ダウンロード済みファイルの削除・リネームに全ファイルアクセスが必要なため、
    // 起動時に一度だけ許可状態を確認し、未許可なら設定へ誘導する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ensureAllFilesAccess(context);
      }
    });
  }

  void _onTabSelected(int index) {
    if (index == _selectedIndex) {
      // 選択中のタブをもう一度押したら、そのタブの最初の画面に戻る
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    _showTab(index);
  }

  /// タブの中の Navigator は、自分で戻れなくなると「アプリでは戻る操作を
  /// 扱わない」と端末へ伝えてしまい、戻るボタンでアプリが閉じる。ここでは
  /// タブ切り替えなどで常に戻る操作を扱うので、扱えると伝え直す。
  bool _onTabNavigation(NavigationNotification notification) {
    if (notification.canHandlePop) return false;
    const NavigationNotification(canHandlePop: true).dispatch(context);
    return true;
  }

  void _handleBack() {
    final NavigatorState? navigator =
        _navigatorKeys[_selectedIndex].currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    if (_selectedIndex != 0) {
      _showTab(0);
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double systemBottom = mediaQuery.padding.bottom;
    final AudioPlayerService audioService = AudioPlayerService.instance;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayFor(palette),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          backgroundColor: palette.bg,
          resizeToAvoidBottomInset: false,
          body: StreamBuilder<int?>(
            stream: audioService.currentIndexStream,
            initialData: audioService.currentIndex,
            builder: (context, _) {
              final bool hasMiniPlayer = audioService.currentSong != null;
              // 浮いている部品の下に中身が隠れないよう、タブの中へ余白として伝える
              final double chromeHeight =
                  _navBottomGap +
                  FloatingNavBar.height +
                  (hasMiniPlayer ? _miniGap + MiniPlayer.height : 0) +
                  16;
              // 浮いている部品(ミニプレイヤーと下タブ)のすりガラスをまとめて描く
              return BackdropGroup(
                child: Stack(
                  children: [
                    MediaQuery(
                      data: mediaQuery.copyWith(
                        padding: mediaQuery.padding.copyWith(
                          bottom: systemBottom + chromeHeight,
                        ),
                      ),
                      child: NotificationListener<NavigationNotification>(
                        onNotification: _onTabNavigation,
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            if (index == _selectedIndex) return;
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                          children: [
                            _TabNavigator(
                              navigatorKey: _navigatorKeys[0],
                              root: const HomeScreen(),
                            ),
                            _TabNavigator(
                              navigatorKey: _navigatorKeys[1],
                              root: const PlaylistsScreen(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasMiniPlayer)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom:
                            systemBottom +
                            _navBottomGap +
                            FloatingNavBar.height +
                            _miniGap,
                        child: const MiniPlayer(),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: systemBottom + _navBottomGap,
                      child: Center(
                        child: FloatingNavBar(
                          items: _navItems,
                          selectedIndex: _selectedIndex,
                          onSelected: _onTabSelected,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// タブごとの画面の積み重ね。横に流して見えなくなっても、開いていた画面や
/// スクロール位置を残す。
class _TabNavigator extends StatefulWidget {
  const _TabNavigator({required this.navigatorKey, required this.root});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget root;

  @override
  State<_TabNavigator> createState() => _TabNavigatorState();
}

class _TabNavigatorState extends State<_TabNavigator>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final GlobalKey<NavigatorState> navigatorKey = widget.navigatorKey;
    final Widget root = widget.root;
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) =>
          MaterialPageRoute(settings: settings, builder: (context) => root),
    );
  }
}
