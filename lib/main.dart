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
  runApp(const MaterialApp(home: MainScreen()));
}
// void main() => runApp(const MaterialApp(home: TestDownloadScreen()));
