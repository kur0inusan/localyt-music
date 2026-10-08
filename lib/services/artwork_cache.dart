import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:localyt_music/models/song.dart';

/// 曲のサムネイル画像をファイルとして用意する。
///
/// サムネイルは mp3 に埋め込まれていて、取り出すにはネイティブ側で
/// ファイルを開く必要があり遅い。一度取り出した画像はキャッシュ
/// ディレクトリに保存し、2回目以降(アプリを再起動した後も)はファイルを読む。
/// 同じファイルを通知・ロック画面のアートワークにも使う。
class ArtworkCache {
  ArtworkCache._();

  static final ArtworkCache instance = ArtworkCache._();

  static const MethodChannel _methodChannel = MethodChannel(
    'com.kuroinusan.localyt_music/youtubedl',
  );

  /// ネイティブ側の取り出しを同時に走らせる数。
  static const int _maxConcurrent = 3;

  /// 取り出しがこれより長くかかったら諦める。返事が来ないまま待ち続けると、
  /// その曲だけでなく順番待ちの曲の画像もずっと出なくなる。
  static const Duration _extractTimeout = Duration(seconds: 15);

  Directory? _dir;

  /// キャッシュディレクトリにあるファイル名。起動時に一度だけ一覧を取り、
  /// 画像があるかどうかをファイルを調べずに答えられるようにする。
  final Set<String> _diskNames = {};

  /// 取り出し済みの結果。値が null なら、その曲には画像が無い。
  final Map<String, File?> _resolved = {};
  final Map<String, Future<File?>> _pending = {};

  /// 読めなかったダウンロード時の画像ファイル(消えている等)。以後は使わない。
  final Set<String> _missingSidecars = {};

  int _running = 0;
  final Queue<Completer<void>> _waiters = Queue();
  final Queue<Completer<void>> _backgroundWaiters = Queue();
  int _prefetchGeneration = 0;

  Future<void> init() async {
    try {
      final Directory dir = Directory(
        p.join((await getTemporaryDirectory()).path, 'artwork'),
      );
      await dir.create(recursive: true);
      await for (final FileSystemEntity entity in dir.list()) {
        _diskNames.add(p.basename(entity.path));
      }
      _dir = dir;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to prepare artwork cache',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 画像のファイルがすでに分かっていれば返す。まだ取り出していない、
  /// または画像が無ければ null。
  File? peek(Song song) {
    final String? sidecar = _sidecar(song);
    if (sidecar != null) return File(sidecar);
    if (_resolved.containsKey(song.path)) return _resolved[song.path];
    final Directory? dir = _dir;
    final String name = _fileName(song.path);
    if (dir == null || !_diskNames.contains(name)) return null;
    return _resolved[song.path] = File(p.join(dir.path, name));
  }

  /// 画像が無いことが分かっている曲か。
  bool hasNoArtwork(Song song) =>
      _sidecar(song) == null &&
      _resolved.containsKey(song.path) &&
      _resolved[song.path] == null;

  /// 画像のファイルが読めなかったとき(端末の空き容量確保でキャッシュが
  /// 消された等)に呼ぶ。覚えている場所を忘れ、次に表示するときに取り出し直す。
  void invalidate(Song song) {
    final String? sidecar = _sidecar(song);
    if (sidecar != null) {
      _missingSidecars.add(sidecar);
      return;
    }
    _resolved.remove(song.path);
    final String name = _fileName(song.path);
    final Directory? dir = _dir;
    if (_diskNames.remove(name) && dir != null) {
      unawaited(
        File(
          p.join(dir.path, name),
        ).delete().then<void>((_) {}, onError: (Object _) {}),
      );
    }
  }

  /// ダウンロード時に保存された画像ファイル。無い・読めなかったなら null。
  String? _sidecar(Song song) {
    final String path = song.thumbnailPath;
    if (path.isEmpty || _missingSidecars.contains(path)) return null;
    return path;
  }

  /// 画像のファイルを用意する。画像が無ければ null。
  Future<File?> load(Song song, {bool background = false}) {
    final File? known = peek(song);
    if (known != null || hasNoArtwork(song)) return Future.value(known);
    // 後始末は値を返さない形にする。`() => _pending.remove(...)` だと取り除いた
    // Future(=この Future 自身)を whenComplete が待ってしまい、永遠に終わらない
    return _pending[song.path] ??= _extract(song, background: background)
        .whenComplete(() {
          _pending.remove(song.path);
        });
  }

  /// 通知に渡すアートワークの場所。まだ取り出していない曲も、
  /// 取り出したときに保存される場所を返す。
  Uri? uriFor(Song song) {
    final String? sidecar = _sidecar(song);
    if (sidecar != null) return Uri.file(sidecar);
    if (hasNoArtwork(song)) return null;
    final Directory? dir = _dir;
    if (dir == null) return null;
    return Uri.file(p.join(dir.path, _fileName(song.path)));
  }

  /// [songs] の画像を [startAt] 番目から順に、画面の表示を邪魔しないよう
  /// 1曲ずつ取り出しておく。新しく呼ぶと前の分は打ち切る。
  Future<void> prefetch(List<Song> songs, {int startAt = 0}) async {
    final int generation = ++_prefetchGeneration;
    for (int i = 0; i < songs.length; i++) {
      if (generation != _prefetchGeneration) return;
      await load(songs[(startAt + i) % songs.length], background: true);
    }
  }

  Future<File?> _extract(Song song, {required bool background}) async {
    final Directory? dir = _dir;
    if (dir == null) return null;
    await _acquire(background: background);
    try {
      final Uint8List? bytes = await _methodChannel
          .invokeMethod<Uint8List>('getAudioThumbnail', {'path': song.path})
          .timeout(_extractTimeout);
      if (bytes == null || bytes.isEmpty) {
        return _resolved[song.path] = null;
      }
      final String name = _fileName(song.path);
      final File file = File(p.join(dir.path, name));
      // 書きかけのファイルを読まれないよう、別名で書いてから置き換える
      final File temp = File('${file.path}.tmp');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
      _diskNames.add(name);
      return _resolved[song.path] = file;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to extract artwork',
        error: e,
        stackTrace: stackTrace,
      );
      // 一時的な失敗かもしれないので「画像なし」とは覚えず、次の表示で取り出し直す
      return null;
    } finally {
      _release();
    }
  }

  Future<void> _acquire({required bool background}) async {
    // 空きがあるときは待っている呼び出しも無い(_release が直接渡すため)
    if (_running < _maxConcurrent) {
      _running++;
      return;
    }
    final Completer<void> completer = Completer();
    (background ? _backgroundWaiters : _waiters).add(completer);
    await completer.future;
  }

  void _release() {
    // 画面に出す分を、先読みより先に通す
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else if (_backgroundWaiters.isNotEmpty) {
      _backgroundWaiters.removeFirst().complete();
    } else {
      _running--;
    }
  }

  /// 曲のパスから、実行のたびに変わらないファイル名を作る(FNV-1a 64bit)。
  static String _fileName(String songPath) {
    int hash = 0xcbf29ce484222325;
    for (final int byte in utf8.encode(songPath)) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    return '${hash.toUnsigned(64).toRadixString(16).padLeft(16, '0')}.jpg';
  }
}
