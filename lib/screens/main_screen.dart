import 'package:flutter/material.dart';
import 'package:localyt_music/screens/home_screen.dart';
import 'package:localyt_music/screens/setting_screen.dart';
import 'package:localyt_music/screens/playlists_screen.dart';
import 'package:localyt_music/widgets/mini_player.dart';
import 'package:localyt_music/widgets/storage_permission_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;

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

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    PlaylistsScreen(),
    SettingScreen(),
  ];

  static const List<String> _titles = <String>['ホーム', 'プレイリスト', '設定'];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'ホーム'),
              NavigationDestination(icon: Icon(Icons.playlist_play_outlined), selectedIcon: Icon(Icons.playlist_play), label: 'プレイリスト'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '設定'),
            ],
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
          ),
        ],
      ),
    );
  }
}