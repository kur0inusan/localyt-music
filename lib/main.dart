import 'package:flutter/material.dart';
import 'package:localyt_music/screens/test_download_screen.dart';

// void main() => runApp(const MaterialApp(home: MainApp()));
void main() => runApp(const MaterialApp(home: TestDownloadScreen()));

class MainApp extends StatefulWidget {
  const MainApp({super.key});
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Minimal StatefulWidget'),
      ),
    );
  }
}
