import 'package:flutter/material.dart';
import 'package:localyt_music/services/file_service.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.playlistName;
    _loadPlaylistInfo();
  }

  @override
  void dispose() {
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

  void _showUpdateNotImplemented() {
    _showSnackBar('更新ロジックはまだ未実装です');
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
                      onPressed: _isSaving ? null : _showUpdateNotImplemented,
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
