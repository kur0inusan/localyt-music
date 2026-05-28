import 'dart:async';
import 'package:flutter/material.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/services/yt_dl_service.dart';

class AddPlaylistScreen extends StatefulWidget {
  const AddPlaylistScreen({super.key});
  @override
  State<AddPlaylistScreen> createState() => _AddPlaylistScreenState();
}

class _AddPlaylistScreenState extends State<AddPlaylistScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final PlaylistManager _playlistManager = PlaylistManager();

  double _progress = 0.0;
  bool _isDownloading = false;
  String _statusText = 'Ready';
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    // Subscribe to download progress stream
    _progressSubscription = YTDLService.progressStream.listen(
      (progress) {
        setState(() {
          _progress = progress;
          _statusText = 'ダウンロード中... ${progress.toStringAsFixed(1)}%';
        });
      },
      onError: (error) {
        setState(() {
          _isDownloading = false;
          _statusText = 'エラー';
        });
        _showSnackBar('エラー: $error');
      },
    );
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Validate directory name (avoid invalid path characters)
  String? _validatePlaylistName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'プレイリスト名を入力してください';
    }
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    if (invalidChars.hasMatch(value)) {
      return '名前にこれらの文字は使用できません: \\ / : * ? " < > |';
    }
    return null;
  }

  // Basic URL validation (checking for youtube link)
  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'プレイリストのURLを入力してください';
    }
    if (!value.contains('youtube.com') && !value.contains('youtu.be')) {
      return 'Youtubeのリンクを入力してください';
    }
    if (!value.contains('list=')) {
      return 'プレイリストのURLを入力してください';
    }
    return null;
  }

  void _startDownloadAndSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isDownloading) return;

    final String playlistName = _nameController.text.trim();
    final String url = _urlController.text.trim();

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = 'ダウンロードを開始します...';
    });

    try {
      await YTDLService.startDownload(url, playlistName);

      await _playlistManager.savePlaylistURL(playlistName, url);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = 'ダウンロード完了';
        });
        _showSnackBar('プレイリストが追加されました');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = 'ダウンロードに失敗しました';
        });
        _showSnackBar('Download error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDownloading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('プレイリストを追加'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'プレイリストをローカルにダウンロードします',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 30),
                
                TextFormField(
                  controller: _nameController,
                  enabled: !_isDownloading,
                  decoration: const InputDecoration(
                    labelText: 'プレイリスト名 (表示名)',
                    hintText: '勉強用',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder),
                  ),
                  validator: _validatePlaylistName,
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _urlController,
                  enabled: !_isDownloading,
                  decoration: const InputDecoration(
                    labelText: 'プレイリストURL',
                    hintText: 'https://www.youtube.com/playlist?list=...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  validator: _validateUrl,
                ),
                const SizedBox(height: 30),

                if (_isDownloading || _progress > 0.0) ...[
                  LinearProgressIndicator(
                    value: _progress / 100.0,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                ],

                ElevatedButton.icon(
                  onPressed: _isDownloading ? null : _startDownloadAndSave,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isDownloading ? 'ダウンロード中...' : 'ダウンロードして追加する'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
