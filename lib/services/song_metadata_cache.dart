import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// mp3 から読んだ曲名・アルバム・アーティスト。
typedef SongMetadata = ({String title, String album, String artist});

/// 曲のメタデータをキャッシュディレクトリに保存しておく。
///
/// メタデータの読み取りはネイティブ側で mp3 を1曲ずつ開くため遅い。
/// ファイルの更新日時と大きさが変わっていなければ、保存した値を使う。
class SongMetadataCache {
  SongMetadataCache._();

  static final SongMetadataCache instance = SongMetadataCache._();

  static const String _fileName = 'song_metadata.json';

  Future<Map<String, _Entry>>? _entries;
  Timer? _saveTimer;

  /// [path] の保存済みメタデータ。ファイルが変わっていれば null。
  Future<SongMetadata?> get(String path, FileStat stat) async {
    final _Entry? entry = (await _load())[path];
    if (entry == null || !entry.matches(stat)) return null;
    return entry.metadata;
  }

  Future<void> put(String path, FileStat stat, SongMetadata metadata) async {
    (await _load())[path] = _Entry(
      metadata,
      stat.modified.millisecondsSinceEpoch,
      stat.size,
    );
    // まとめて読んだ直後に何度も書かないよう、少し待ってから保存する
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
  }

  Future<Map<String, _Entry>> _load() => _entries ??= _read();

  Future<File> _file() async =>
      File(p.join((await getTemporaryDirectory()).path, _fileName));

  Future<Map<String, _Entry>> _read() async {
    try {
      final File file = await _file();
      if (!await file.exists()) return {};
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return {};
      final Map<String, _Entry> entries = {};
      decoded.forEach((path, value) {
        final _Entry? entry = _Entry.fromJson(value);
        if (entry != null) entries[path] = entry;
      });
      return entries;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to read song metadata cache',
        error: e,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  Future<void> _save() async {
    try {
      final Map<String, _Entry> entries = await _load();
      final File file = await _file();
      final File temp = File('${file.path}.tmp');
      await temp.writeAsString(
        jsonEncode({
          for (final MapEntry<String, _Entry> entry in entries.entries)
            entry.key: entry.value.toJson(),
        }),
        flush: true,
      );
      await temp.rename(file.path);
    } catch (e, stackTrace) {
      developer.log(
        'Failed to save song metadata cache',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

class _Entry {
  const _Entry(this.metadata, this.modifiedMs, this.size);

  final SongMetadata metadata;
  final int modifiedMs;
  final int size;

  bool matches(FileStat stat) =>
      stat.modified.millisecondsSinceEpoch == modifiedMs && stat.size == size;

  List<Object> toJson() => [
    metadata.title,
    metadata.album,
    metadata.artist,
    modifiedMs,
    size,
  ];

  static _Entry? fromJson(Object? json) {
    if (json is! List || json.length != 5) return null;
    final [title, album, artist, modifiedMs, size] = json;
    if (title is! String ||
        album is! String ||
        artist is! String ||
        modifiedMs is! int ||
        size is! int) {
      return null;
    }
    return _Entry(
      (title: title, album: album, artist: artist),
      modifiedMs,
      size,
    );
  }
}
