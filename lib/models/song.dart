class Song {
  final String title;
  final String album;
  final String artist;
  final String path;
  final String thumbnailPath;

  /// ファイルの更新日時。MP3はダウンロード時に変換・作成されるため追加日として扱う。
  final DateTime? addedAt;

  const Song(
    this.title,
    this.album,
    this.artist, [
    this.path = '',
    this.thumbnailPath = '',
    this.addedAt,
  ]);

  String get albam => album;
}
