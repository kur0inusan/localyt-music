import 'package:flutter/material.dart';

/// 1行に収まらないときだけ、横に流して全体を見せるテキスト。
///
/// 行数が変わらないので、下に並ぶボタンの位置が文字の長さで動かない。
/// 先頭で少し止まってから流れ、末尾の後に先頭がつながって繰り返す。
/// 端末で「アニメーションを削除」が有効なら、流さずに省略記号で切る。
class MarqueeText extends StatefulWidget {
  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;

  /// 収まるときの寄せ方。
  final TextAlign textAlign;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  /// 流れる速さ(論理ピクセル/秒)。
  static const double _velocity = 36;

  /// 末尾と、つなげて出す先頭との間隔。
  static const double _gap = 48;

  /// 先頭で止まっている時間。
  static const Duration _pause = Duration(seconds: 2);

  late final AnimationController _controller;

  /// 1周で動く距離(文字の幅+間隔)。流していなければ null。
  double? _distance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 曲が変わったら先頭から流し直す
    if (oldWidget.text != widget.text) _distance = null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run(double distance) {
    if (_distance == distance) return;
    _distance = distance;
    final Duration scroll = Duration(
      milliseconds: (distance / _velocity * 1000).round(),
    );
    // build 中にアニメーションの値を変えないよう、描画後に始める
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _distance != distance) return;
      _controller
        ..duration = _pause + scroll
        ..value = 0
        ..repeat();
    });
  }

  void _stop() {
    if (_distance == null) return;
    _distance = null;
    _controller.stop();
  }

  double _offset(double distance) {
    final int total = _controller.duration?.inMilliseconds ?? 0;
    final int pause = _pause.inMilliseconds;
    if (total <= pause) return 0;
    final double elapsed = _controller.value * total;
    if (elapsed <= pause) return 0;
    return (elapsed - pause) / (total - pause) * distance;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = DefaultTextStyle.of(
      context,
    ).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final double textWidth = painter.width;
        final double height = painter.height;
        painter.dispose();

        if (textWidth <= constraints.maxWidth ||
            MediaQuery.disableAnimationsOf(context)) {
          _stop();
          return Text(
            widget.text,
            style: style,
            textAlign: widget.textAlign,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          );
        }

        final double distance = textWidth + _gap;
        _run(distance);
        final Widget line = Text(
          widget.text,
          style: style,
          maxLines: 1,
          softWrap: false,
        );
        // 流れている間は毎フレーム描き直すので、周りと分けておく
        return RepaintBoundary(
          child: SizedBox(
            width: constraints.maxWidth,
            height: height,
            child: ShaderMask(
              // 両端を薄くして、文字が切れているのではなく流れていると分かるようにする
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0x00000000),
                  Color(0xFF000000),
                  Color(0xFF000000),
                  Color(0x00000000),
                ],
                stops: [0, 0.06, 0.94, 1],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(-_offset(distance), 0),
                    child: child,
                  ),
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 0,
                    maxWidth: double.infinity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        line,
                        const SizedBox(width: _gap),
                        line,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
