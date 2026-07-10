import 'package:flutter/material.dart';
import 'package:localyt_music/services/network_service.dart';

/// ダウンロード開始前にネットワーク種別を確認し、必要であれば
/// 警告ダイアログを表示してユーザーに続行するか確認する。
///
/// 戻り値はダウンロードを続行してよいかどうか(true=続行)。
Future<bool> confirmProceedOnCurrentNetwork(BuildContext context) async {
  final NetworkType networkType = await NetworkService().getNetworkType();

  if (!context.mounted) return false;

  switch (networkType) {
    case NetworkType.wifi:
      // Wi-Fi接続時は確認不要でそのまま続行する。
      return true;

    case NetworkType.mobile:
    case NetworkType.other:
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('モバイルデータ通信'),
            content: const Text(
              'Wi-Fiに接続されていません。モバイルデータ通信を使用してダウンロードしますか？'
              '通信量にご注意ください。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('続行'),
              ),
            ],
          );
        },
      );
      return proceed ?? false;

    case NetworkType.none:
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('ネットワーク未接続'),
            content: const Text('インターネットに接続されていません。接続を確認してください。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return false;
  }
}
