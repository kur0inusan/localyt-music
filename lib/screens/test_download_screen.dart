import 'dart:async';
import 'package:flutter/material.dart';
import 'package:localyt_music/services/yt_dl_service.dart'; // Serviceのパスは環境に合わせて変更してください

class TestDownloadScreen extends StatefulWidget {
  const TestDownloadScreen({Key? key}) : super(key: key);

  @override
  State<TestDownloadScreen> createState() => _TestDownloadScreenState();
}

class _TestDownloadScreenState extends State<TestDownloadScreen> {
  final TextEditingController _urlController = TextEditingController(
    // テスト用の初期値（適宜変更してください）
    text: 'https://music.youtube.com/watch?v=pS31mdpYuh4&si=VQ5j2NtvwD6eBjVC',
  );

  double _progress = 0.0;
  bool _isDownloading = false;
  String _statusText = '待機中';
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    // 進捗ストリームの購読を開始
    _progressSubscription = YTDLService.progressStream.listen(
          (progress) {
        setState(() {
          _progress = progress;
          _statusText = 'ダウンロード中... ${progress.toStringAsFixed(1)}%';

          // 100%に到達したら完了状態にする
          if (progress >= 100.0) {
            _statusText = 'ダウンロード完了！';
            _isDownloading = false;
          }
        });
      },
      onError: (error) {
        // ストリームでエラーが飛んできた場合
        setState(() {
          _isDownloading = false;
          _statusText = 'エラーが発生しました';
        });
        _showSnackBar('進捗取得エラー: $error');
      },
    );
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  // ダウンロード開始処理
  void _startDownload() async {
    if (_urlController.text.isEmpty) {
      _showSnackBar('URLを入力してください');
      return;
    }

    // 多重起動防止
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = 'ダウンロード準備中...';
    });

    try {
      // Serviceを呼び出してダウンロード開始
      // 第2引数のpathはKotlin側で "/localyt_music/{path}/youtubedl-android/" となります
      await YTDLService.startDownload(_urlController.text, 'test_folder');

      // executeが完了したら（Kotlin側からresult.successが返ってきたら）
      if (mounted && _progress < 100.0) {
        setState(() {
          _statusText = 'ダウンロード処理は終了しましたが、100%に到達していません';
          _isDownloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = 'エラーが発生しました';
        });
        _showSnackBar('ダウンロードエラー: $e');
      }
    }
  }

  // Snackバー表示用ヘルパー
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ダウンロード動作テスト'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // URL入力欄
            TextField(
              controller: _urlController,
              enabled: !_isDownloading, // ダウンロード中は編集不可
              decoration: const InputDecoration(
                labelText: 'YouTube URL',
                border: OutlineInputBorder(),
                hintText: 'https://www.youtube.com/watch?v=...',
              ),
            ),
            const SizedBox(height: 32),

            // 進捗バー
            LinearProgressIndicator(
              value: _isDownloading || _progress == 100.0 ? _progress / 100.0 : null,
              // 待機中は不定バー(indeterminate)、ダウンロード中は定バー(determinate)
              minHeight: 12,
            ),
            const SizedBox(height: 16),

            // ステータステキスト
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 32),

            // ダウンロードボタン
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : _startDownload,
              icon: _isDownloading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.download),
              label: Text(_isDownloading ? '処理中...' : 'ダウンロード開始'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}