import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
// import 'package:localyt_music/screens/test_download_screen.dart';
import 'package:localyt_music/screens/main_screen.dart';
import 'package:localyt_music/services/play_history_service.dart';
import 'package:localyt_music/theme/app_theme.dart';
import 'package:localyt_music/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.kuroinusan.localyt_music.audio',
    androidNotificationChannelName: '音楽再生',
    androidNotificationOngoing: true,
  );
  await ThemeController.instance.load();
  await PlayHistoryService.instance.load();

  runApp(const LocalYtMusicApp());
}

/// テーマコントローラを購読し、選択中テーマを [MaterialApp] に反映するルート。
class LocalYtMusicApp extends StatelessWidget {
  const LocalYtMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController controller = ThemeController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final AppThemeData theme = controller.currentTheme;
        return MaterialApp(
          title: 'LocalYT Music',
          theme: theme.light,
          darkTheme: theme.dark,
          themeMode: controller.themeMode,
          home: const MainScreen(),
        );
      },
    );
  }
}
// void main() => runApp(const MaterialApp(home: TestDownloadScreen()));
