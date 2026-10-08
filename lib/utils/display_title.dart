import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/theme/theme_controller.dart';

final RegExp _bracketTag = RegExp(r'【[^】]*】');
final RegExp _officialParen = RegExp(
  r'[（(][^）)]*(Official|ver\.|Mix|Video)[^）)]*[）)]',
  caseSensitive: false,
);
final RegExp _officialAudioSuffix = RegExp(
  r'\s*[/／]\s*Official Audio',
  caseSensitive: false,
);
final RegExp _spaces = RegExp(r'\s+');

/// YouTube の動画タイトルから【MV】や (Official Music Video) などを外す。
/// 表示用で、元のファイル名やデータは変えない。外した結果が空なら元のまま返す。
String cleanSongTitle(String title) {
  final String cleaned = title
      .replaceAll(_bracketTag, ' ')
      .replaceAll(_officialParen, ' ')
      .replaceFirst(_officialAudioSuffix, '')
      .replaceAll(_spaces, ' ')
      .trim();
  return cleaned.isEmpty ? title : cleaned;
}

/// 設定(曲名を整えて表示する)に従った表示用の曲名。
String displayTitle(Song song) => ThemeController.instance.cleanTitles
    ? _cleanTitles.putIfAbsent(song.title, () => cleanSongTitle(song.title))
    : song.title;

/// 整えた曲名。一覧を描くたびに正規表現をかけ直さないよう覚えておく。
final Map<String, String> _cleanTitles = {};
