import 'package:flutter/material.dart';
import 'package:localyt_music/theme/app_palette.dart';
import 'package:localyt_music/widgets/glass_surface.dart';

class FloatingNavItem {
  const FloatingNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// 画面下中央に浮かぶカプセル型のタブ。
/// 選ばれているタブだけアクセント色の面に名前を出し、他はアイコンだけにする。
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double height = 56;

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return GlassSurface(
      borderRadius: 999,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _NavButton(
              item: items[i],
              selected: i == selectedIndex,
              palette: palette,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 44,
            constraints: const BoxConstraints(minWidth: 52),
            padding: selected
                ? const EdgeInsets.only(left: 14, right: 18)
                : EdgeInsets.zero,
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: selected ? palette.accent : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: selected ? palette.onAccent : palette.textMuted,
                  fill: selected ? 1 : 0,
                  weight: selected ? 400 : 300,
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.onAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
