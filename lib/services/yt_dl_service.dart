import 'package:flutter/services.dart';

class YTDLService{
  static const MethodChannel _methodChannel = MethodChannel('com.kuroinusan.localyt_music/youtubedl');
  static const EventChannel _eventChannel = EventChannel('com.kuroinusan.localyt_music/youtubedl_event');

  static bool _isYoutubePlaylist(String url) {
    try {
      final uri = Uri.parse(url);

      final isYoutubeHost = uri.host.contains('youtube.com') || uri.host.contains('youtu.be');
      if (!isYoutubeHost) return false;

      if (uri.queryParameters.containsKey('list')) {
        return true;
      }

      if (uri.host == 'youtu.be' && uri.queryParameters.containsKey('list')) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Stream<double> get progressStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return (event as double?) ?? 0.0;
    });
  }

  static Future<void> startDownload(String url, String path) async {
    if (!_isYoutubePlaylist(url)) {
      throw Exception('Invalid YouTube URL');
    }

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