import 'package:flutter/services.dart';

class YTDLService{
  static const MethodChannel _methodChannel = MethodChannel('com.kuroinusan.localyt_music/youtubedl');
  static const EventChannel _eventChannel = EventChannel('com.kuroinusan.localyt_music/youtubedl_event');

  static Stream<double> get progressStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return (event as double?) ?? 0.0;
    });
  }

  static Future<void> startDownload(String url, String path) async {
    try {
      await _methodChannel.invokeMethod('downloadYT', {
        'url': url,
        'path': path,
      });
    } on PlatformException catch (e) {
      print("Failed to start download: ${e.message}");
      rethrow;
    }
  }
}