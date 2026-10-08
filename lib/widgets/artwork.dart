import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' hide Image;
import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/services/artwork_cache.dart';
import 'package:localyt_music/theme/app_palette.dart';

/// 曲のサムネイル。
///
/// YouTube のサムネイルは横長なので、中央を正方形(枠の形)に切り抜いて見せる。
/// 4:3 の hqdefault は上下に黒帯があるため、一度16:9に収めて黒帯を落としてから
/// 切り抜く。サムネイルが無ければプレイリスト名の頭文字を出す。
///
/// 覚えていた画像ファイルが読めなかったとき(端末がキャッシュを消した等)は、
/// 一度だけ曲から取り出し直す。
class Artwork extends StatefulWidget {
  const Artwork({
    super.key,
    required this.song,
    required this.height,
    this.width,
    this.radius = 10,
    this.circle = false,
    this.playing = false,
    this.fallbackLabel,
  });

  final Song? song;
  final double height;

  /// 省略すると正方形。double.infinity で親の幅いっぱい。
  final double? width;
  final double radius;
  final bool circle;

  /// 再生中の曲としてイコライザを重ねる。
  final bool playing;

  /// サムネイルが無いときに頭文字を出す文字列。省略時はアルバム(≒プレイリスト名)。
  final String? fallbackLabel;

  @override
  State<Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends State<Artwork> {
  /// 読めなかったので取り出し直した曲。同じ曲で繰り返さない。
  String? _retriedPath;

  double get height => widget.height;

  @override
  void didUpdateWidget(Artwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.path != widget.song?.path) _retriedPath = null;
  }

  void _onImageError(Song song) {
    if (_retriedPath == song.path) return;
    _retriedPath = song.path;
    ArtworkCache.instance.invalidate(song);
    // 画像の読み込み失敗は build 中に知らされるので、作り直しは次のフレームで行う
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.song?.path == song.path) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Song? song = widget.song;
    final double? width = widget.width;

    final ArtworkCache cache = ArtworkCache.instance;
    final File? known = song == null ? null : cache.peek(song);
    Widget content;
    if (song == null || cache.hasNoArtwork(song)) {
      content = _fallback(palette);
    } else if (known != null) {
      content = _ArtworkImage(
        image: FileImage(known),
        fallback: _fallback(palette),
        onError: () => _onImageError(song),
      );
    } else {
      // 初めて表示する曲だけ、取り出すまで地の色で待つ
      content = FutureBuilder<File?>(
        future: cache.load(song),
        builder: (context, snapshot) {
          final File? file = snapshot.data;
          if (file != null) {
            return _ArtworkImage(
              image: FileImage(file),
              fallback: _fallback(palette),
              onError: () => _onImageError(song),
            );
          }
          if (snapshot.connectionState == ConnectionState.done) {
            return _fallback(palette);
          }
          return ColoredBox(color: palette.artFallback);
        },
      );
    }

    if (widget.playing) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          content,
          ColoredBox(
            color: palette.playingOverlay,
            child: Icon(
              Symbols.graphic_eq_rounded,
              color: palette.accent,
              size: 22,
              weight: 400,
            ),
          ),
        ],
      );
    }

    final Widget sized = SizedBox(
      width: width ?? height,
      height: height,
      child: content,
    );
    return widget.circle
        ? ClipOval(child: sized)
        : ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: sized,
          );
  }

  Widget _fallback(AppPalette palette) {
    final String label = (widget.fallbackLabel ?? widget.song?.album ?? '')
        .trim();
    return ColoredBox(
      color: palette.artFallback,
      child: Center(
        child: label.isEmpty
            ? Icon(
                Symbols.music_note_rounded,
                color: palette.textFaint,
                size: height * 0.36,
              )
            : Text(
                String.fromCharCode(label.runes.first),
                style: AppFonts.displayStyle(
                  fontSize: height * 0.3,
                  color: palette.textFaint,
                ),
              ),
      ),
    );
  }
}

/// 曲のサムネイルを大きくぼかした背景。
///
/// ぼかしは画面全体にかけると毎フレーム重いので、小さく縮めた画像に一度だけ
/// かけておき、それを引き伸ばして敷く(縮めた分、軽いぼかしで同じ見た目になる)。
/// ぼかした画像は曲ごとに少数だけ覚えておき、開き直したときにすぐ出す。
class ArtworkBackdrop extends StatefulWidget {
  const ArtworkBackdrop({super.key, required this.song, this.opacity = 0.6});

  final Song song;
  final double opacity;

  @override
  State<ArtworkBackdrop> createState() => _ArtworkBackdropState();
}

class _ArtworkBackdropState extends State<ArtworkBackdrop> {
  /// ぼかした画像の一辺と、その大きさでのぼかしの強さ。
  static const int _size = 48;
  static const double _sigma = 3;
  static const int _cacheLimit = 12;

  /// 曲のパスごとのぼかした画像。挿入順を使った簡単な LRU。
  static final Map<String, ui.Image> _cache = {};
  static final Map<String, Future<ui.Image?>> _pending = {};

  /// 表示中の画像(キャッシュの画像の複製。手放すときに dispose する)。
  ui.Image? _image;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ArtworkBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 次の画像ができるまでは前の曲の背景を出したままにする
    if (oldWidget.song.path != widget.song.path) _resolve();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _show(String path, ui.Image? image) {
    if (_imagePath == path && _image != null && image != null) return;
    final ui.Image? old = _image;
    _image = image?.clone();
    _imagePath = path;
    old?.dispose();
  }

  /// 覚えている画像があればすぐ(次の build で)出し、無ければ作ってから出す。
  Future<void> _resolve() async {
    final String path = widget.song.path;
    final ui.Image? cached = _cache.remove(path);
    if (cached != null) {
      _cache[path] = cached;
      _show(path, cached);
      return;
    }
    final ui.Image? image = await (_pending[path] ??= _bake(widget.song));
    if (!mounted || widget.song.path != path) return;
    setState(() => _show(path, image));
  }

  static Future<ui.Image?> _bake(Song song) async {
    final String path = song.path;
    try {
      final ArtworkCache cache = ArtworkCache.instance;
      File? file = cache.peek(song) ?? await cache.load(song);
      if (file == null) return null;
      Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
        if (bytes.isEmpty) throw StateError('empty artwork');
      } catch (_) {
        // 覚えていたファイルが消えていたら、一度だけ曲から取り出し直す
        cache.invalidate(song);
        file = await cache.load(song);
        if (file == null) return null;
        bytes = await file.readAsBytes();
      }
      final Codec codec = await instantiateImageCodec(bytes, targetWidth: 160);
      final FrameInfo frame = await codec.getNextFrame();
      codec.dispose();
      final ui.Image source = frame.image;

      // サムネイルと同じく、16:9 の中央を正方形に切り抜いて黒帯を落とす
      final double width = source.width.toDouble();
      final double side = math.min(width * 9 / 16, source.height.toDouble());
      final Rect crop = Rect.fromCenter(
        center: Offset(width / 2, source.height / 2),
        width: side,
        height: side,
      );
      final PictureRecorder recorder = PictureRecorder();
      Canvas(recorder).drawImageRect(
        source,
        crop,
        Rect.fromLTWH(0, 0, _size.toDouble(), _size.toDouble()),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..imageFilter = ImageFilter.blur(
            sigmaX: _sigma,
            sigmaY: _sigma,
            tileMode: TileMode.clamp,
          ),
      );
      final Picture picture = recorder.endRecording();
      final ui.Image blurred = await picture.toImage(_size, _size);
      picture.dispose();
      source.dispose();

      _cache[path] = blurred;
      if (_cache.length > _cacheLimit) {
        final String oldest = _cache.keys.first;
        _cache.remove(oldest)?.dispose();
      }
      return blurred;
    } catch (_) {
      return null;
    } finally {
      _pending.remove(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? image = _image;
    if (image == null) return const SizedBox.shrink();
    return RawImage(
      image: image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      // Opacity で包むと画面全体の重ね描きになるので、描くときに薄くする
      opacity: AlwaysStoppedAnimation(widget.opacity),
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({
    required this.image,
    required this.fallback,
    required this.onError,
  });

  final ImageProvider image;

  /// ファイルが消えていて読めなかったときに出すもの。
  final Widget fallback;

  /// 読めなかったときに呼ぶ(取り出し直しを頼む)。
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size box = constraints.biggest;
        // 枠を覆う最小の16:9。4:3 の画像はこの中に cover で収めると
        // 上下の黒帯がちょうど外れ、はみ出た左右は枠で切り落とされる。
        final Size frame = box.width / box.height < 16 / 9
            ? Size(box.height * 16 / 9, box.height)
            : Size(box.width, box.width * 9 / 16);
        final ImageProvider provider = ResizeImage(
          image,
          width: (frame.width * dpr).round().clamp(32, 1280),
        );
        return ClipRect(
          child: OverflowBox(
            minWidth: frame.width,
            maxWidth: frame.width,
            minHeight: frame.height,
            maxHeight: frame.height,
            child: Image(
              image: provider,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                // 失敗した結果を画像のキャッシュに残さない(取り出し直した
                // ファイルは同じ場所に置かれるため、残すとまた失敗が出る)
                provider.evict();
                onError();
                return fallback;
              },
            ),
          ),
        );
      },
    );
  }
}
