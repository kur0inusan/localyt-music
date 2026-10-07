import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:localyt_music/models/song.dart';

/// 前回の再生位置。アプリ起動直後の「続きから再生」に使う。
class ResumePoint {
  const ResumePoint({
    required this.song,
    required this.index,
    required this.position,
  });

  final Song song;
  final int index;
  final Duration position;
}

/// 再生履歴(最近再生した曲・再生回数)と、続きから再生するための状態を保存する。
///
/// 履歴はアプリ専用領域の JSON ファイルに保存する。SharedPreferences は
/// プレイリスト名をキーにURLを保存しているため、キー衝突を避けて別にしている。
/// 再生キューは曲数が多いと大きくなるため、頻繁に書き込む再生位置とは
/// 別ファイルにして、キューが変わったときだけ書き込む。
class PlayHistoryService extends ChangeNotifier {
  PlayHistoryService._();

  static final PlayHistoryService instance = PlayHistoryService._();

  static const String _historyFileName = 'play_history.json';
  static const String _resumeStateFileName = 'resume_state.json';
  static const String _resumeQueueFileName = 'resume_queue.json';
  static const int _maxRecent = 30;

  Directory? _dir;
  final Map<String, Song> _songs = {};
  final List<String> _recent = [];
  final Map<String, int> _counts = {};
  ResumePoint? _resumePoint;
  Future<void> _writeChain = Future.value();

  ResumePoint? get resumePoint => _resumePoint;

  /// 最近再生した曲を新しい順に返す。削除済みのファイルは除外する。
  List<Song> recentSongs({int limit = 10}) {
    final List<Song> songs = [];
    for (final String path in _recent) {
      if (songs.length >= limit) break;
      final Song? song = _songs[path];
      if (song != null && File(path).existsSync()) songs.add(song);
    }
    return songs;
  }

  /// 再生回数の多い曲を返す。同じ回数なら最近再生した曲を優先する。
  List<({Song song, int count})> frequentSongs({int limit = 5}) {
    int recency(String path) {
      final int index = _recent.indexOf(path);
      return index < 0 ? _recent.length : index;
    }

    final List<String> paths = _counts.keys.toList()
      ..sort((a, b) {
        final int byCount = _counts[b]!.compareTo(_counts[a]!);
        return byCount != 0 ? byCount : recency(a).compareTo(recency(b));
      });

    final List<({Song song, int count})> result = [];
    for (final String path in paths) {
      if (result.length >= limit) break;
      final Song? song = _songs[path];
      if (song != null && File(path).existsSync()) {
        result.add((song: song, count: _counts[path]!));
      }
    }
    return result;
  }

  /// 起動時に保存済みの履歴と再生位置を読み込む。
  Future<void> load() async {
    try {
      _dir = await getApplicationSupportDirectory();

      final Object? history = await _readJson(_historyFileName);
      if (history is Map) {
        final Object? songs = history['songs'];
        if (songs is Map) {
          for (final Object? value in songs.values) {
            final Song? song = Song.fromJson(value);
            if (song != null) _songs[song.path] = song;
          }
        }
        final Object? recent = history['recent'];
        if (recent is List) {
          _recent.addAll(recent.whereType<String>().where(_songs.containsKey));
        }
        final Object? counts = history['counts'];
        if (counts is Map) {
          counts.forEach((key, value) {
            if (key is String && value is int && _songs.containsKey(key)) {
              _counts[key] = value;
            }
          });
        }
      }

      final Object? state = await _readJson(_resumeStateFileName);
      if (state is Map) {
        final Song? song = Song.fromJson(state['song']);
        final Object? index = state['index'];
        final Object? positionMs = state['positionMs'];
        if (song != null && index is int && positionMs is int) {
          _resumePoint = ResumePoint(
            song: song,
            index: index,
            position: Duration(milliseconds: positionMs),
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to load play history',
        error: e,
        stackTrace: stackTrace,
      );
    }
    notifyListeners();
  }

  void recordPlay(Song song) {
    _songs[song.path] = song;
    _recent
      ..remove(song.path)
      ..insert(0, song.path);
    if (_recent.length > _maxRecent) {
      _recent.removeRange(_maxRecent, _recent.length);
    }
    _counts[song.path] = (_counts[song.path] ?? 0) + 1;
    notifyListeners();

    _enqueueWrite(_historyFileName, {
      // 再生回数を持つ曲の表示情報だけを残す
      'songs': {
        for (final String path in _counts.keys) path: _songs[path]!.toJson(),
      },
      'recent': _recent,
      'counts': _counts,
    });
  }

  void saveResumeQueue(List<Song> queue) {
    _enqueueWrite(_resumeQueueFileName, {
      'queue': [for (final Song song in queue) song.toJson()],
    });
  }

  void saveResumePoint(Song song, int index, Duration position) {
    _resumePoint = ResumePoint(song: song, index: index, position: position);
    _enqueueWrite(_resumeStateFileName, {
      'song': song.toJson(),
      'index': index,
      'positionMs': position.inMilliseconds,
    });
  }

  Future<List<Song>> loadResumeQueue() async {
    await _writeChain;
    final Object? data = await _readJson(_resumeQueueFileName);
    if (data is! Map) return [];
    final Object? queue = data['queue'];
    if (queue is! List) return [];
    return queue.map(Song.fromJson).whereType<Song>().toList();
  }

  Future<Object?> _readJson(String fileName) async {
    final Directory? dir = _dir;
    if (dir == null) return null;
    final File file = File(p.join(dir.path, fileName));
    try {
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString());
    } catch (e, stackTrace) {
      developer.log(
        'Failed to read $fileName',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// 書き込みを直列化し、一時ファイル経由で置き換えて途中で壊れないようにする。
  void _enqueueWrite(String fileName, Object data) {
    // 呼び出し時点の内容で確定させる
    final String content = jsonEncode(data);
    _writeChain = _writeChain.then((_) async {
      final Directory? dir = _dir;
      if (dir == null) return;
      try {
        final File file = File(p.join(dir.path, fileName));
        final File temp = File('${file.path}.tmp');
        await temp.writeAsString(content, flush: true);
        await temp.rename(file.path);
      } catch (e, stackTrace) {
        developer.log(
          'Failed to write $fileName',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });
  }
}
