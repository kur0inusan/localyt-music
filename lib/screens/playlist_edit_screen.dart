import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localyt_music/services/file_service.dart';
import 'package:localyt_music/services/yt_dl_service.dart';

class PlaylistEditScreen extends StatefulWidget {
  final String playlistName;

  const PlaylistEditScreen({super.key, required this.playlistName});

  @override
  State<PlaylistEditScreen> createState() => _PlaylistEditScreenState();
}

class _PlaylistEditScreenState extends State<PlaylistEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final PlaylistsManager _playlistsManager = PlaylistsManager();

  String _playlistUrl = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUpdating = false;
  double _progress = 0.0;
  String _statusText = '';
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.playlistName;
    _loadPlaylistInfo();
    _progressSubscription = YTDLService.progressStream.listen(
      (progress) {
        if (!mounted) return;
        if (!_isUpdating) return;
        setState(() {
          _progress = progress;
          _statusText = '更新中... ${progress.toStringAsFixed(1)}%';
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
          _isUpdating = false;
          _statusText = '更新に失敗しました';
        });
        _showSnackBar('更新エラー: $error');
      },
    );
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylistInfo() async {
    final String url = await _playlistsManager.getPlayListURL(
      widget.playlistName,
    );
    if (!mounted) return;
    setState(() {
      _playlistUrl = url;
      _isLoading = false;
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validatePlaylistName(String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'プレイリスト名を入力してください';
    }
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    if (invalidChars.hasMatch(name)) {
      return '名前にこれらの文字は使用できません: \\ / : * ? " < > |';
    }
    if (name.length > 30) {
      return '30文字以内にしてください';
    }
    return null;
  }

  Future<void> _renamePlaylist() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    final String newName = _nameController.text.trim();
    if (newName == widget.playlistName) {
      _showSnackBar('名前は変更されていません');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _playlistsManager.renamePlaylist(widget.playlistName, newName);
      if (!mounted) return;
      _showSnackBar('プレイリスト名を変更しました');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('名前の変更に失敗しました: $e');
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deletePlaylist() async {
    if (_isSaving) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('プレイリストを削除しますか？'),
          content: Text('「${widget.playlistName}」の保存済みファイルも削除されます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _playlistsManager.deletePlaylist(widget.playlistName);
      if (!mounted) return;
      _showSnackBar('プレイリストを削除しました');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('削除に失敗しました: $e');
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _updatePlaylist() async {
    if (_isSaving) return;
    if (_playlistUrl.isEmpty) {
      _showSnackBar('プレイリストURLが保存されていません');
      return;
    }

    setState(() {
      _isSaving = true;
      _isUpdating = true;
      _progress = 0.0;
      _statusText = '更新を開始します...';
    });

    try {
      await YTDLService.startDownload(_playlistUrl, widget.playlistName);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isUpdating = false;
        _statusText = '更新完了';
      });
      _showSnackBar('プレイリストを更新しました');
      Navigator.pop(context, 'updated');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isUpdating = false;
        _statusText = '更新に失敗しました';
      });
      _showSnackBar('更新に失敗しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プレイリストを編集')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'プレイリスト名',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder),
                      ),
                      validator: _validatePlaylistName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _playlistUrl.isEmpty
                          ? 'URL未保存'
                          : _playlistUrl,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'プレイリストURL',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_isUpdating || _progress > 0.0) ...[
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
                      onPressed: _isSaving ? null : _renamePlaylist,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.drive_file_rename_outline),
                      label: const Text('名前を変更'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : _updatePlaylist,
                      icon: const Icon(Icons.sync),
                      label: const Text('更新'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _deletePlaylist,
                      icon: const Icon(Icons.delete),
                      label: const Text('削除'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
