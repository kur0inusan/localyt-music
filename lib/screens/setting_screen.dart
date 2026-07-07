import 'package:flutter/material.dart';

import 'package:localyt_music/theme/app_theme.dart';
import 'package:localyt_music/theme/theme_controller.dart';

/// 設定画面。テーマ(デザイン)とライト/ダークモードを切り替える。
class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController controller = ThemeController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SectionHeader(
              icon: Icons.palette_outlined,
              title: 'テーマ',
              subtitle: 'アプリ全体のデザインを切り替えます',
            ),
            const SizedBox(height: 8),
            for (final theme in AppThemes.all)
              _ThemeOptionCard(
                theme: theme,
                selected: controller.themeId == theme.id,
                onTap: () => controller.setThemeId(theme.id),
              ),
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.brightness_6_outlined,
              title: '表示モード',
              subtitle: 'ライト・ダークの切り替え',
            ),
            const SizedBox(height: 12),
            _ThemeModeSelector(
              mode: controller.themeMode,
              onChanged: controller.setThemeMode,
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// テーマ1件分の選択カード。左側にプレビュー、右側に名前と説明。
class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final AppThemeData theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? cs.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ThemePreview(theme: theme),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(theme.icon, size: 18, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          theme.label,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? cs.onPrimaryContainer
                                : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      theme.description,
                      style: tt.bodySmall?.copyWith(
                        color: selected
                            ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// テーマの代表色を使った小さなミニ画面プレビュー。
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme});

  final AppThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.previewBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 8,
              decoration: BoxDecoration(
                color: theme.previewSurface,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.previewPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 12,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.previewSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('システム'),
          icon: Icon(Icons.settings_suggest_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('ライト'),
          icon: Icon(Icons.light_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('ダーク'),
          icon: Icon(Icons.dark_mode_outlined),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}
