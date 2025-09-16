import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'download_state.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  Map<String, String> _items = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final map = await DownloadState.load();
    if (!mounted) return;
    setState(() => _items = map);
  }

  Future<void> _open(String path) async {
    await OpenFilex.open(path);
  }

  Future<void> _remove(String url) async {
    final map = Map<String, String>.from(_items);
    final path = map.remove(url);
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
    await DownloadState.save(map);
    if (!mounted) return;
    setState(() => _items = map);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _items.entries.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: entries.isEmpty
          ? const Center(child: Text('No downloads yet'))
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final e = entries[index];
                final url = e.key;
                final path = e.value;
                final name = path.split(Platform.pathSeparator).last;
                return ListTile(
                  leading: const Icon(Icons.video_library),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _open(path),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(url),
                  ),
                );
              },
            ),
    );
  }
}
