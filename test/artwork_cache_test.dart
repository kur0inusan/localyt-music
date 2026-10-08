import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/services/artwork_cache.dart';
import 'package:localyt_music/theme/app_palette.dart';
import 'package:localyt_music/theme/app_theme.dart';
import 'package:localyt_music/widgets/artwork.dart';

void main() {
  test('取り出しが終わったら、待っている側にも終わったと伝わる', () async {
    // 以前は後始末が自分自身の完了を待ってしまい、待ち続けて黒いままになった
    const Song song = Song('t', 'Jazz', 'a', '/music/Jazz/c.mp3');
    await expectLater(
      ArtworkCache.instance.load(song).timeout(const Duration(seconds: 2)),
      completion(isNull),
    );
  });

  test('読めなかったダウンロード時の画像は、以後使わない', () {
    const Song song = Song(
      't',
      'Rock',
      'a',
      '/music/Rock/a.mp3',
      '/music/Rock/a.jpg',
    );
    final ArtworkCache cache = ArtworkCache.instance;
    expect(cache.peek(song)?.path, '/music/Rock/a.jpg');

    cache.invalidate(song);
    expect(cache.peek(song), isNull);
    // 「画像なし」とは扱わず、曲から取り出し直す対象にする
    expect(cache.hasNoArtwork(song), isFalse);
  });

  testWidgets('画像ファイルが消えていたら、取り出し直しを頼む', (tester) async {
    final String missing =
        '${Directory.systemTemp.path}/localyt_missing_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final Song song = Song('t', 'Pop', 'a', '/music/Pop/b.mp3', missing);
    expect(ArtworkCache.instance.peek(song)?.path, missing);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppPalette.modernDark),
        home: Center(child: Artwork(song: song, height: 48)),
      ),
    );
    // ファイルの読み込みは実際の入出力なので、待ってから描き直す
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(ArtworkCache.instance.peek(song)?.path, isNot(missing));
    // 取り出し直しの間も頭文字を出し、黒いままにしない
    expect(find.text('P'), findsOneWidget);
  });
}
