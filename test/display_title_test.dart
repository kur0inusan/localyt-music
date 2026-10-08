import 'package:flutter_test/flutter_test.dart';
import 'package:localyt_music/utils/display_title.dart';

void main() {
  group('cleanSongTitle', () {
    test('【】と (Official …) を外す', () {
      expect(
        cleanSongTitle('【MV】群青の街 / 水野カナ（Official Music Video）'),
        '群青の街 / 水野カナ',
      );
    });

    test('ver. や Mix を含む括弧を外す', () {
      expect(cleanSongTitle('夜明けのテーマ (Piano ver.)'), '夜明けのテーマ');
      expect(cleanSongTitle('ミッドナイト・ドライブ【City Pop Mix】'), 'ミッドナイト・ドライブ');
    });

    test('末尾の / Official Audio を外す', () {
      expect(cleanSongTitle('小さな惑星 / Official Audio'), '小さな惑星');
    });

    test('関係ない括弧は残す', () {
      expect(cleanSongTitle('夜明けのテーマ (Piano Cover)'), '夜明けのテーマ (Piano Cover)');
    });

    test('外すと空になる場合は元のまま', () {
      expect(cleanSongTitle('【作業用BGM】'), '【作業用BGM】');
    });
  });
}
