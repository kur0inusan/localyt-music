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

  Map<String, Object?> toJson() => {
    'title': title,
    'album': album,
    'artist': artist,
    'path': path,
    'thumbnailPath': thumbnailPath,
  };

  /// 保存データから復元する。パスが無い等の不正なデータは null を返す。
  static Song? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? path = json['path'];
    if (path is! String || path.isEmpty) return null;
    String text(String key) {
      final Object? value = json[key];
      return value is String ? value : '';
    }

    return Song(
      text('title'),
      text('album'),
      text('artist'),
      path,
      text('thumbnailPath'),
    );
  }
}
