import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
// import 'package:localyt_music/screens/test_download_screen.dart';
import 'package:localyt_music/screens/main_screen.dart';
import 'package:localyt_music/services/artwork_cache.dart';
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
  // 下タブとミニプレイヤーを浮かべるため、システムのナビゲーションバーの裏まで描く
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _registerFontLicenses();
  await Future.wait([
    ThemeController.instance.load(),
    PlayHistoryService.instance.load(),
    ArtworkCache.instance.init(),
  ]);

  runApp(const LocalYtMusicApp());
}

/// 同梱している書体(SIL Open Font License)をライセンス表示に載せる。
void _registerFontLicenses() {
  const Map<String, String> fonts = {
    'LINE Seed JP': 'assets/fonts/LINESeedJP-OFL.txt',
    'Murecho': 'assets/fonts/Murecho-OFL.txt',
    'Geist Mono': 'assets/fonts/GeistMono-OFL.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry<String, String> font in fonts.entries) {
      yield LicenseEntryWithLineBreaks([
        font.key,
      ], await rootBundle.loadString(font.value));
    }
  });
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
