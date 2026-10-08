import 'package:flutter/material.dart';
import 'package:localyt_music/theme/app_palette.dart';

/// 丸い再生ボタン。面は同じ色相の明→暗のグラデーション。
class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 56,
    this.iconSize = 30,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: palette.playGradient,
        boxShadow: palette.raisedShadows,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(
            icon,
            size: iconSize,
            color: palette.onAccent,
            fill: 1,
            weight: 400,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// 枠線だけの四角いアイコンボタン(シャッフル・更新など、再生の脇の操作)。
class OutlineIconButton extends StatelessWidget {
  const OutlineIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.tooltip,
    this.child,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;

  /// アイコンの代わりに表示する(進捗表示など)。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final BorderRadius radius = BorderRadius.circular(palette.radiusButton);
    final bool raised = palette.raisedShadows.isNotEmpty;
    final Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: raised ? palette.surface : null,
        borderRadius: radius,
        border: raised ? null : Border.all(color: palette.border),
        boxShadow: palette.raisedShadows,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: child ?? Icon(icon, size: 22, color: palette.text),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// セクション見出しの右に置く、枠線の小さな文字ボタン(「すべて再生」など)。
class ChipButton extends StatelessWidget {
  const ChipButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final BorderRadius radius = BorderRadius.circular(palette.radiusChip);
    return Material(
      type: MaterialType.transparency,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: palette.border),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(fontSize: 12, color: palette.text),
          ),
        ),
      ),
    );
  }
}
