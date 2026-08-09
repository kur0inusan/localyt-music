import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

enum DownloadEventType { progress, completed, error }

class DownloadEvent {
  const DownloadEvent({
    required this.type,
    required this.jobId,
    required this.path,
    this.progress,
    this.message,
  });

  final DownloadEventType type;
  final String jobId;
  final String path;
  final double? progress;
  final String? message;

  factory DownloadEvent.fromPlatform(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid download event');
    }
    final Map<Object?, Object?> event = Map<Object?, Object?>.from(value);
    final String type = event['type']?.toString() ?? '';
    return DownloadEvent(
      type: switch (type) {
        'progress' => DownloadEventType.progress,
        'completed' => DownloadEventType.completed,
        'error' => DownloadEventType.error,
        _ => throw FormatException('Unknown download event type: $type'),
      },
      jobId: event['jobId']?.toString() ?? '',
      path: event['path']?.toString() ?? '',
      progress: (event['progress'] as num?)?.toDouble(),
      message: event['message']?.toString(),
    );
  }
}

class YTDLService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.kuroinusan.localyt_music/youtubedl',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.kuroinusan.localyt_music/youtubedl_event',
  );
  static int _jobSequence = 0;

  static final Stream<DownloadEvent> _downloadEvents = _eventChannel
      .receiveBroadcastStream()
      .map(DownloadEvent.fromPlatform)
      .asBroadcastStream();

  static bool _isYoutubePlaylist(String url) {
    try {
      final uri = Uri.parse(url);

      final isYoutubeHost =
          uri.host.contains('youtube.com') || uri.host.contains('youtu.be');
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
    return _downloadEvents.map((event) {
      return switch (event.type) {
        DownloadEventType.progress => event.progress ?? 0.0,
        DownloadEventType.completed => 100.0,
        DownloadEventType.error => -1.0,
      };
    });
  }

  static Stream<DownloadEvent> get downloadEvents => _downloadEvents;

  /// ネイティブ処理を開始し、該当ジョブの完了または失敗イベントまで待機する。
  static Future<void> startDownload(
    String url,
    String path, {
    bool isUpdate = false,
  }) async {
    if (!_isYoutubePlaylist(url)) {
      throw Exception('Invalid YouTube URL');
    }

    final String jobId =
        '${DateTime.now().microsecondsSinceEpoch}-${_jobSequence++}';
    final Completer<void> completion = Completer<void>();
    late final StreamSubscription<DownloadEvent> subscription;
    subscription = _downloadEvents
        .where((event) => event.jobId == jobId)
        .listen(
          (event) {
            switch (event.type) {
              case DownloadEventType.progress:
                break;
              case DownloadEventType.completed:
                if (!completion.isCompleted) completion.complete();
                break;
              case DownloadEventType.error:
                if (!completion.isCompleted) {
                  completion.completeError(
                    Exception(event.message ?? 'Download failed'),
                  );
                }
                break;
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completion.isCompleted) {
              completion.completeError(error, stackTrace);
            }
          },
        );

    try {
      await _methodChannel.invokeMethod('downloadYT', {
        'url': url,
        'path': path,
        'jobId': jobId,
        'isUpdate': isUpdate,
      });
      await completion.future;
    } on PlatformException catch (e, stackTrace) {
      developer.log(
        'Failed to download playlist',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      await subscription.cancel();
    }
  }
}
