import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
// import 'package:localyt_music/screens/test_download_screen.dart';
import 'package:localyt_music/screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.kuroinusan.localyt_music.audio',
    androidNotificationChannelName: '音楽再生',
    androidNotificationOngoing: true,
  );
  final ColorScheme lightScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00897B),
  );
  final ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00897B),
    brightness: Brightness.dark,
  );

  runApp(
    MaterialApp(
      title: 'LocalYT Music',
      theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
    ),
  );
}
// void main() => runApp(const MaterialApp(home: TestDownloadScreen()));
