import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:localyt_music/theme/app_palette.dart';

/// 画面の上に浮かぶ部品(下タブ・ミニプレイヤー・再生操作・次に再生)の面。
///
/// すりガラスのテーマでは、背景をぼかして彩度を上げ、半透明の面と
/// 上端の細い明るい線を重ねる(CSS の backdrop-filter: blur(22px)
/// saturate(170%) 相当)。ニューモフィズムでは不透明の面と影で浮かせる。
///
/// 同じ画面のすりガラスは、上にある [BackdropGroup] でまとめて1回のぼかしで
/// 描く(重ならない部品どうしに限る)。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.borderRadius,
    required this.child,
    this.height,
    this.width,
    this.padding = EdgeInsets.zero,
  });

  final double borderRadius;
  final Widget child;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry padding;

  static final ImageFilter _backdropFilter = ImageFilter.compose(
    outer: ColorFilter.matrix(_saturation(1.7)),
    inner: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
  );

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    if (!palette.glassBlur) {
      return Container(
        height: height,
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: palette.glassFill,
          borderRadius: radius,
          boxShadow: palette.raisedShadows,
        ),
        child: child,
      );
    }

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: palette.glassShadow,
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter.grouped(
          filter: _backdropFilter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.glassFill,
              borderRadius: radius,
              border: Border.all(color: palette.glassBorder),
            ),
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                Padding(padding: padding, child: child),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 1,
                  child: ColoredBox(color: palette.glassHighlight),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 彩度を [s] 倍にする色行列(Rec.709 の輝度係数)。
  static List<double> _saturation(double s) {
    const double lr = 0.2126;
    const double lg = 0.7152;
    const double lb = 0.0722;
    final double r = (1 - s) * lr;
    final double g = (1 - s) * lg;
    final double b = (1 - s) * lb;
    return [
      r + s, g, b, 0, 0, //
      r, g + s, b, 0, 0, //
      r, g, b + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}
