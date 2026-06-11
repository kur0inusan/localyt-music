class Song {
  final String title;
  final String album;
  final String artist;
  final String path;
  final String thumbnailPath;

  const Song(
    this.title,
    this.album,
    this.artist, [
    this.path = '',
    this.thumbnailPath = '',
  ]);

  String get albam => album;
}
