import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/services/play_history_service.dart';
import 'package:path/path.dart' as p;

Song _song(String playlist, String title) => Song(
  title,
  playlist,
  '',
  '${PlaylistsManager.storagePath}/$playlist/$title.mp3',
);

void main() {
  final DateTime now = DateTime(2026, 10, 7, 12);

  group('playlistOf', () {
    test('ダウンロード先のプレイリスト名を返す', () {
      expect(PlayHistoryService.playlistOf(_song('Rock', 'a').path), 'Rock');
    });

    test('ダウンロード先の外なら null', () {
      expect(PlayHistoryService.playlistOf('/sdcard/Music/a.mp3'), isNull);
    });
  });

  group('recommend', () {
    test('よく聴いていたのに最近再生していない曲を優先する', () {
      final PlayHistoryService history = PlayHistoryService.forTesting();
      final Song favorite = _song('Rock', 'favorite');
      for (int i = 0; i < 5; i++) {
        history.recordPlay(favorite, at: now.subtract(Duration(days: 40 + i)));
      }
      final List<Song> library = [
        favorite,
        for (int i = 0; i < 20; i++) _song('Pop', 'new$i'),
      ];

      final List<Recommendation> result = history.recommend(library, now: now);

      expect(result.first.song.path, favorite.path);
      expect(result.first.reason, 'しばらく聴いていません');
    });

    test('直近に再生した曲は出さない', () {
      final PlayHistoryService history = PlayHistoryService.forTesting();
      final Song justPlayed = _song('Rock', 'just');
      history.recordPlay(
        justPlayed,
        at: now.subtract(const Duration(hours: 3)),
      );

      final List<Recommendation> result = history.recommend([
        justPlayed,
        _song('Rock', 'other'),
      ], now: now);

      expect(result.map((r) => r.song.path), isNot(contains(justPlayed.path)));
    });

    test('よく聴いているプレイリストの未再生曲に理由を付ける', () {
      final PlayHistoryService history = PlayHistoryService.forTesting();
      for (int i = 0; i < 4; i++) {
        history.recordPlay(
          _song('Rock', 'played$i'),
          at: now.subtract(Duration(days: 3 + i)),
        );
      }
      final Song unplayed = _song('Rock', 'unplayed');

      final List<Recommendation> result = history.recommend([
        unplayed,
      ], now: now);

      expect(result.single.reason, '「Rock」をよく聴いているので');
    });

    test('件数の上限と、同じ日なら同じ結果になることを守る', () {
      final PlayHistoryService history = PlayHistoryService.forTesting();
      final List<Song> library = [
        for (int i = 0; i < 50; i++) _song('Pop', 'song$i'),
      ];

      final List<Recommendation> first = history.recommend(
        library,
        limit: 10,
        now: now,
      );
      final List<Recommendation> second = history.recommend(
        library,
        limit: 10,
        now: now.add(const Duration(hours: 5)),
      );

      expect(first, hasLength(10));
      expect(
        second.map((r) => r.song.path),
        orderedEquals(first.map((r) => r.song.path)),
      );
    });

    test('同じ曲が重複していても1回だけ出す', () {
      final PlayHistoryService history = PlayHistoryService.forTesting();
      final Song song = _song('Pop', 'dup');

      final List<Recommendation> result = history.recommend([
        song,
        song,
      ], now: now);

      expect(result, hasLength(1));
    });
  });

  group('recentFrequentSongs', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('play_history_test');
    });

    tearDown(() {
      dir.deleteSync(recursive: true);
    });

    Song fileSong(String name) {
      final File file = File(p.join(dir.path, '$name.mp3'))..createSync();
      return Song(name, '', '', file.path);
    }

    test('2週間以内に2回以上再生した曲を回数順に返す', () {
      final PlayHistoryService history = PlayHistoryService.forTesting();
      final Song often = fileSong('often');
      final Song twice = fileSong('twice');
      final Song once = fileSong('once');
      final Song old = fileSong('old');
      for (int i = 0; i < 3; i++) {
        history.recordPlay(often, at: now.subtract(Duration(days: i)));
      }
      history.recordPlay(twice, at: now.subtract(const Duration(days: 1)));
      history.recordPlay(twice, at: now.subtract(const Duration(days: 2)));
      history.recordPlay(once, at: now.subtract(const Duration(days: 1)));
      history.recordPlay(old, at: now.subtract(const Duration(days: 20)));
      history.recordPlay(old, at: now.subtract(const Duration(days: 21)));

      final result = history.recentFrequentSongs(now: now);

      expect(result.map((e) => e.song.title), ['often', 'twice']);
      expect(result.map((e) => e.count), [3, 2]);
    });

    test('再生回数のリセットでは最近再生した曲を残す', () {
      final PlayHistoryService history = PlayHistoryService.forTesting();
      final Song song = fileSong('song');
      history.recordPlay(song, at: now.subtract(const Duration(days: 1)));
      history.recordPlay(song, at: now);

      history.resetPlayCounts();

      expect(history.totalPlayCount, 0);
      expect(history.frequentSongs(), isEmpty);
      expect(history.recentFrequentSongs(now: now), isEmpty);
      expect(history.recentSongs().map((s) => s.path), [song.path]);
      expect(history.hasHistory, isTrue);
    });

    test('すべて削除すると最近再生した曲と続きから再生も消える', () {
      final PlayHistoryService history = PlayHistoryService.forTesting();
      final Song song = fileSong('song');
      history.recordPlay(song, at: now);
      history.saveResumePoint(song, 0, const Duration(seconds: 30));

      history.clearAllHistory();

      expect(history.recentSongs(), isEmpty);
      expect(history.resumePoint, isNull);
      expect(history.hasHistory, isFalse);
    });

    test('記録をオフにすると再生しても履歴が増えない', () async {
      final PlayHistoryService history = PlayHistoryService.forTesting();
      await history.setRecording(false);

      history.recordPlay(fileSong('song'), at: now);

      expect(history.totalPlayCount, 0);
      expect(history.recentSongs(), isEmpty);
    });
  });
}
