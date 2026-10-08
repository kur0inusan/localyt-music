import 'package:flutter/material.dart';

import 'package:localyt_music/services/play_history_service.dart';
import 'package:localyt_music/theme/app_theme.dart';
import 'package:localyt_music/theme/theme_controller.dart';

/// 設定画面。テーマ(デザイン)・ライト/ダークモードの切り替えと、
/// 再生履歴の記録・リセットを行う。
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
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.history,
              title: '再生履歴',
              subtitle: 'ホーム画面のおすすめやランキングに使います',
            ),
            const SizedBox(height: 8),
            const _PlayHistorySettings(),
          ],
        );
      },
    );
  }
}

/// 再生履歴の記録のオン/オフ、再生回数のリセット、履歴の削除。
class _PlayHistorySettings extends StatelessWidget {
  const _PlayHistorySettings();

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _resetPlayCounts(BuildContext context) async {
    final bool confirmed = await _confirm(
      context,
      title: '再生回数をリセット',
      message:
          '全曲の再生回数を0に戻します。再生回数ランキング・最近よく聴く曲・'
          'おすすめの傾向が初期化されます。\n'
          '最近再生した曲と続きから再生は残ります。',
      action: 'リセット',
    );
    if (!confirmed || !context.mounted) return;
    PlayHistoryService.instance.resetPlayCounts();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('再生回数をリセットしました')));
  }

  Future<void> _clearAllHistory(BuildContext context) async {
    final bool confirmed = await _confirm(
      context,
      title: '再生履歴をすべて削除',
      message: '再生回数に加えて、最近再生した曲と続きから再生の情報も削除します。',
      action: '削除',
    );
    if (!confirmed || !context.mounted) return;
    PlayHistoryService.instance.clearAllHistory();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('再生履歴を削除しました')));
  }

  @override
  Widget build(BuildContext context) {
    final PlayHistoryService history = PlayHistoryService.instance;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final int songCount = history.countedSongCount;
        final int playCount = history.totalPlayCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.edit_note),
                    title: const Text('再生履歴を記録する'),
                    subtitle: const Text('オフの間は再生回数や最近再生した曲を更新しません'),
                    value: history.isRecording,
                    onChanged: history.setRecording,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('再生回数をリセット'),
                    subtitle: Text(
                      playCount == 0
                          ? '記録された再生回数はありません'
                          : '$songCount曲・合計$playCount回',
                    ),
                    enabled: playCount > 0,
                    onTap: () => _resetPlayCounts(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: history.hasHistory ? cs.error : null,
                    ),
                    title: Text(
                      '再生履歴をすべて削除',
                      style: history.hasHistory
                          ? TextStyle(color: cs.error)
                          : null,
                    ),
                    subtitle: const Text('最近再生した曲・続きから再生も削除します'),
                    enabled: history.hasHistory,
                    onTap: () => _clearAllHistory(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '再生履歴はこの端末のアプリ内にだけ保存され、'
              'アプリを再インストールすると消えます。',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
