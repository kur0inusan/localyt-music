import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/services/file_service.dart';

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

/// ホーム画面のおすすめ1曲分。[reason] は「しばらく聴いていません」などの表示用。
class Recommendation {
  const Recommendation({required this.song, required this.reason});

  final Song song;
  final String reason;
}

/// 再生履歴(最近再生した曲・再生回数)と、続きから再生するための状態を保存する。
///
/// 履歴はアプリ専用領域の JSON ファイルに保存する。SharedPreferences は
/// プレイリスト名をキーにURLを保存しているため、キー衝突を避けて別にしている。
/// 再生キューは曲数が多いと大きくなるため、頻繁に書き込む再生位置とは
/// 別ファイルにして、キューが変わったときだけ書き込む。
/// 再インストールでリセットするため、これらのファイルは Android の自動
/// バックアップ対象から除外している(res/xml/backup_rules.xml ほか)。
class PlayHistoryService extends ChangeNotifier {
  PlayHistoryService._();

  /// ファイルに保存しない単体テスト用のインスタンスを作る。
  @visibleForTesting
  PlayHistoryService.forTesting();

  static final PlayHistoryService instance = PlayHistoryService._();

  static const String _historyFileName = 'play_history.json';
  static const String _resumeStateFileName = 'resume_state.json';
  static const String _resumeQueueFileName = 'resume_queue.json';
  static const int _maxRecent = 30;

  /// 再生日時を残す期間。「最近よく聴く曲」とおすすめの傾向計算に使う。
  static const Duration _playLogRetention = Duration(days: 30);
  static const Duration _recentFrequentWindow = Duration(days: 14);

  /// 直近に再生した曲はおすすめに出さない。
  static const Duration _recommendCooldown = Duration(days: 2);

  /// この期間再生していない、よく聴いていた曲を「しばらく聴いていません」で出す。
  static const Duration _forgottenAfter = Duration(days: 14);
  static const int _forgottenMinCount = 3;

  Directory? _dir;
  final Map<String, Song> _songs = {};
  final List<String> _recent = [];
  final Map<String, int> _counts = {};
  final Map<String, DateTime> _lastPlayed = {};

  /// 曲ごとの再生日時(古い順)。[_playLogRetention] より古いものは捨てる。
  final Map<String, List<DateTime>> _playLog = {};
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

  /// 直近2週間に2回以上再生した曲を、その期間の再生回数が多い順に返す。
  /// 1回だけの曲は「最近再生した曲」と変わらないので含めない。
  List<({Song song, int count})> recentFrequentSongs({
    int limit = 5,
    DateTime? now,
  }) {
    final DateTime since = (now ?? DateTime.now()).subtract(
      _recentFrequentWindow,
    );
    final Map<String, int> counts = {};
    _playLog.forEach((path, times) {
      final int count = times.where((time) => time.isAfter(since)).length;
      if (count >= 2) counts[path] = count;
    });

    final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final List<String> paths = counts.keys.toList()
      ..sort((a, b) {
        final int byCount = counts[b]!.compareTo(counts[a]!);
        if (byCount != 0) return byCount;
        return (_lastPlayed[b] ?? epoch).compareTo(_lastPlayed[a] ?? epoch);
      });

    final List<({Song song, int count})> result = [];
    for (final String path in paths) {
      if (result.length >= limit) break;
      final Song? song = _songs[path];
      if (song != null && File(path).existsSync()) {
        result.add((song: song, count: counts[path]!));
      }
    }
    return result;
  }

  /// [library] の中からおすすめの曲を選ぶ。
  ///
  /// - よく聴いていたのに最近再生していない曲
  /// - 最近よく聴いているプレイリストの、まだ再生していない曲
  /// - まだ再生していない曲
  ///
  /// を優先し、日付をシードにした揺らぎを加える。同じ日なら同じ並びになり、
  /// 日が変わると入れ替わる。同じ理由の曲ばかりにならないよう件数を制限する。
  List<Recommendation> recommend(
    List<Song> library, {
    int limit = 10,
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();

    // 最近の再生がどのプレイリストに偏っているか
    final DateTime affinitySince = current.subtract(_playLogRetention);
    final Map<String, int> playlistPlays = {};
    int totalPlays = 0;
    _playLog.forEach((path, times) {
      final String? playlist = playlistOf(path);
      if (playlist == null) return;
      final int count = times
          .where((time) => time.isAfter(affinitySince))
          .length;
      playlistPlays[playlist] = (playlistPlays[playlist] ?? 0) + count;
      totalPlays += count;
    });

    final Random random = Random(
      current.year * 10000 + current.month * 100 + current.day,
    );
    final Set<String> seen = {};
    final List<({Recommendation recommendation, double score})> scored = [];
    for (final Song song in library) {
      if (!seen.add(song.path)) continue;
      final DateTime? lastPlayed = _lastPlayed[song.path];
      if (lastPlayed != null &&
          current.difference(lastPlayed) < _recommendCooldown) {
        continue;
      }

      final int count = _counts[song.path] ?? 0;
      final String? playlist = playlistOf(song.path);
      final double affinity = playlist == null || totalPlays == 0
          ? 0
          : (playlistPlays[playlist] ?? 0) / totalPlays;

      final double score;
      final String reason;
      if (count >= _forgottenMinCount &&
          lastPlayed != null &&
          current.difference(lastPlayed) >= _forgottenAfter) {
        score = 1.0 + min(count, 20) / 20;
        reason = 'しばらく聴いていません';
      } else if (count == 0 && playlist != null && affinity >= 0.2) {
        score = 0.6 + affinity;
        reason = '「$playlist」をよく聴いているので';
      } else if (count == 0) {
        score = 0.4;
        reason = 'まだ聴いていない曲';
      } else {
        score = 0.2 + affinity * 0.5;
        reason = playlist == null ? 'ピックアップ' : '「$playlist」から';
      }
      scored.add((
        recommendation: Recommendation(song: song, reason: reason),
        score: score + random.nextDouble() * 0.6,
      ));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final int maxPerReason = max(1, (limit * 0.4).ceil());
    final Map<String, int> perReason = {};
    final List<Recommendation> picked = [];
    final List<Recommendation> overflow = [];
    for (final entry in scored) {
      final Recommendation recommendation = entry.recommendation;
      final int used = perReason[recommendation.reason] ?? 0;
      if (used < maxPerReason) {
        perReason[recommendation.reason] = used + 1;
        picked.add(recommendation);
        if (picked.length >= limit) return picked;
      } else {
        overflow.add(recommendation);
      }
    }
    // 理由の種類が少ないときは、制限で外した曲で埋める
    picked.addAll(overflow.take(limit - picked.length));
    return picked;
  }

  /// 曲ファイルが入っているプレイリスト名。ダウンロード先の外なら null。
  @visibleForTesting
  static String? playlistOf(String path) {
    const String root = PlaylistsManager.storagePath;
    if (!p.isWithin(root, path)) return null;
    return p.split(p.relative(path, from: root)).first;
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
        final Object? lastPlayed = history['lastPlayed'];
        if (lastPlayed is Map) {
          lastPlayed.forEach((key, value) {
            if (key is String && value is int && _songs.containsKey(key)) {
              _lastPlayed[key] = DateTime.fromMillisecondsSinceEpoch(value);
            }
          });
        }
        final Object? playLog = history['playLog'];
        if (playLog is Map) {
          playLog.forEach((key, value) {
            if (key is String && value is List && _songs.containsKey(key)) {
              _playLog[key] = [
                for (final int ms in value.whereType<int>())
                  DateTime.fromMillisecondsSinceEpoch(ms),
              ];
            }
          });
          _prunePlayLog(DateTime.now());
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

  void recordPlay(Song song, {DateTime? at}) {
    final DateTime playedAt = at ?? DateTime.now();
    final Song? known = _songs[song.path];
    // おすすめから再生した曲はメタデータを読んでいないので、
    // 既にアーティスト名などを知っていればそちらを残す。
    if (known == null || song.artist.isNotEmpty || known.artist.isEmpty) {
      _songs[song.path] = song;
    }
    _recent
      ..remove(song.path)
      ..insert(0, song.path);
    if (_recent.length > _maxRecent) {
      _recent.removeRange(_maxRecent, _recent.length);
    }
    _counts[song.path] = (_counts[song.path] ?? 0) + 1;
    _lastPlayed[song.path] = playedAt;
    _playLog.putIfAbsent(song.path, () => []).add(playedAt);
    _prunePlayLog(playedAt);
    notifyListeners();

    _enqueueWrite(_historyFileName, {
      // 再生回数を持つ曲の表示情報だけを残す
      'songs': {
        for (final String path in _counts.keys) path: _songs[path]!.toJson(),
      },
      'recent': _recent,
      'counts': _counts,
      'lastPlayed': {
        for (final MapEntry<String, DateTime> entry in _lastPlayed.entries)
          entry.key: entry.value.millisecondsSinceEpoch,
      },
      'playLog': {
        for (final MapEntry<String, List<DateTime>> entry in _playLog.entries)
          entry.key: [
            for (final DateTime time in entry.value)
              time.millisecondsSinceEpoch,
          ],
      },
    });
  }

  void _prunePlayLog(DateTime now) {
    final DateTime since = now.subtract(_playLogRetention);
    _playLog.updateAll(
      (path, times) => times.where((time) => time.isAfter(since)).toList(),
    );
    _playLog.removeWhere((path, times) => times.isEmpty);
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
