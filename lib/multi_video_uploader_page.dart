import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:minio/minio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_compress/video_compress.dart';

class MultiVideoUploaderPage extends StatefulWidget {
	const MultiVideoUploaderPage({super.key});

	@override
	State<MultiVideoUploaderPage> createState() => _MultiVideoUploaderPageState();
}

class _MultiVideoUploaderPageState extends State<MultiVideoUploaderPage> {
	List<PlatformFile> _files = [];
	bool _loading = false;
	bool _compress = false;
	VideoQuality _quality = VideoQuality.MediumQuality;

	// R2 config
	String _accountId = '';
	String _accessKey = '';
	String _secretKey = '';
	String _bucket = '';
	String _customDomain = '';

	// Per-file progress 0..1
	final Map<String, double> _progress = {};
	final Map<String, String> _status = {};

	@override
	void initState() {
		super.initState();
		_loadR2Configuration();
	}

	Future<void> _loadR2Configuration() async {
		try {
			final doc = await FirebaseFirestore.instance.collection('app_config').doc('r2_settings').get();
			if (doc.exists) {
				final d = doc.data()!;
				setState(() {
					_accountId = (d['accountId'] ?? '').toString();
					_accessKey = (d['accessKeyId'] ?? '').toString();
					_secretKey = (d['secretAccessKey'] ?? '').toString();
					_bucket = (d['bucketName'] ?? '').toString();
					_customDomain = (d['customDomain'] ?? '').toString();
				});
			}
		} catch (_) {}
	}

	Future<void> _pick() async {
		final res = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true, withData: false);
		if (res == null || res.files.isEmpty) return;
		setState(() {
			_files = res.files.where((f) => (f.path ?? '').isNotEmpty).toList();
			_progress.clear();
			_status.clear();
		});
	}

	bool get _r2Ok => _accountId.isNotEmpty && _accessKey.isNotEmpty && _secretKey.isNotEmpty && _bucket.isNotEmpty;

	Future<void> _startUpload() async {
		if (_files.isEmpty) return;
		if (!_r2Ok) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('R2 not configured')));
			return;
		}
		setState(() => _loading = true);

		final minio = Minio(
			endPoint: '$_accountId.r2.cloudflarestorage.com',
			accessKey: _accessKey,
			secretKey: _secretKey,
			useSSL: true,
		);

		final List<Map<String, dynamic>> attachments = [];

		for (final file in _files) {
			final key = file.identifier ?? file.name;
			_status[key] = 'Preparing…';
			_progress[key] = 0.0;
			setState(() {});

			try {
				// Prepare source path
				final srcPath = file.path!;
				File toUpload = File(srcPath);

				// Optional compression
				if (_compress) {
					_status[key] = 'Compressing…';
					setState(() {});
					final compressed = await VideoCompress.compressVideo(
						srcPath,
						quality: _quality,
						deleteOrigin: false,
						includeAudio: true,
						frameRate: 30,
					);
					if (compressed != null && compressed.file != null) {
						toUpload = compressed.file!;
					}
				}

				// Basic metadata
				int? width;
				int? height;
				Duration? duration;
				try {
					final info = await VideoCompress.getMediaInfo(toUpload.path);
					width = info.width;
					height = info.height;
					if (info.duration != null) duration = Duration(milliseconds: info.duration!.round());
				} catch (_) {}

				// Thumbnail - improved quality for better viewing
				String? thumbPublicUrl;
				try {
					final thumbFile = await VideoCompress.getFileThumbnail(toUpload.path, quality: 50, position: 800);
					final thumbKey = _buildThumbKey(file.name);
					final thumbSize = await thumbFile.length();
					final thumbStream = thumbFile.openRead().map((c) => Uint8List.fromList(c));
					await minio.putObject(_bucket, thumbKey, thumbStream, size: thumbSize);
					thumbPublicUrl = _publicUrl(thumbKey);
				} catch (_) {}

				// Upload video
				final total = await toUpload.length();
				int sent = 0;
				_status[key] = 'Uploading…';
				setState(() {});

				final videoKey = _buildVideoKey(file.name);
				final stream = toUpload.openRead().transform(
					StreamTransformer.fromHandlers(handleData: (List<int> chunk, EventSink<Uint8List> sink) {
						sent += chunk.length;
						_progress[key] = total > 0 ? (sent / total) : 0.0;
						sink.add(Uint8List.fromList(chunk));
						if (mounted) setState(() {});
					}),
				);

				await minio.putObject(_bucket, videoKey, stream, size: total);

				// Save metadata in videos collection
				final videoUrl = _publicUrl(videoKey);
				final meta = {
					'type': 'r2',
					'url': videoUrl,
					if (thumbPublicUrl != null) 'thumbnailUrl': thumbPublicUrl,
					'meta': {
						if (width != null) 'width': width,
						if (height != null) 'height': height,
						if (width != null && height != null && height != 0) 'aspect': width / height,
						if (duration != null) 'durationMs': duration.inMilliseconds,
					},
					'uploadedAt': FieldValue.serverTimestamp(),
				};

				// Also persist in videos collection for reference
				try { await FirebaseFirestore.instance.collection('videos').add({...meta, 'fileName': videoKey, 'bucket': _bucket}); } catch (_) {}

				attachments.add(meta);
				_status[key] = 'Done';
				_progress[key] = 1.0;
				setState(() {});
			} catch (e) {
				_status[key] = 'Failed';
				setState(() {});
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload ${file.name}: $e')));
			}
		}

		setState(() => _loading = false);
		if (!mounted) return;
		if (attachments.isNotEmpty) {
			Navigator.of(context).pop(attachments);
		}
	}

	String _buildVideoKey(String name) {
		final ts = DateTime.now().millisecondsSinceEpoch;
		final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
		return 'videos/${ts}_$safe';
	}

	String _buildThumbKey(String name) {
		final ts = DateTime.now().millisecondsSinceEpoch;
		var base = name;
		final i = base.lastIndexOf('.');
		if (i > 0) base = base.substring(0, i);
		base = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
		return 'videos/${ts}_$base.jpg';
	}

	String _publicUrl(String objectKey) {
		return _customDomain.isNotEmpty
				? '$_customDomain/$objectKey'
				: 'https://$_accountId.r2.cloudflarestorage.com/$objectKey';
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Upload multiple videos'),
				actions: [
					IconButton(
						tooltip: 'Open files',
						icon: const Icon(Icons.folder_open),
						onPressed: _loading ? null : () async {
							// Quick access to the last output file (debug)
							final k = _progress.keys.isNotEmpty ? _progress.keys.last : null;
							if (k != null) await OpenFilex.open(k);
						},
					),
				],
			),
			body: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
								ElevatedButton.icon(
									onPressed: _loading ? null : _pick,
									icon: const Icon(Icons.video_library_outlined),
									label: const Text('Pick videos'),
								),
								const SizedBox(width: 12),
								Row(children: [
									Checkbox(value: _compress, onChanged: _loading ? null : (v) => setState(() => _compress = v ?? false)),
									const Text('Compress'),
								]),
								const SizedBox(width: 8),
								if (_compress)
									DropdownButton<VideoQuality>(
										value: _quality,
										onChanged: _loading ? null : (q) => setState(() => _quality = q ?? _quality),
										items: const [
											DropdownMenuItem(value: VideoQuality.HighestQuality, child: Text('High')),
											DropdownMenuItem(value: VideoQuality.MediumQuality, child: Text('Medium')),
											DropdownMenuItem(value: VideoQuality.LowQuality, child: Text('Low')),
										],
									),
							],
						),
						const SizedBox(height: 12),
						if (!_r2Ok)
							Container(
								padding: const EdgeInsets.all(12),
								decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.3))),
								child: const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('R2 configuration missing. Set it in the single uploader first.'))]),
							),
						const SizedBox(height: 8),
						Expanded(
							child: _files.isEmpty
									? const Center(child: Text('No videos selected'))
									: ListView.separated(
											itemCount: _files.length,
											separatorBuilder: (_, __) => const SizedBox(height: 8),
											itemBuilder: (_, i) {
												final f = _files[i];
												final key = f.identifier ?? f.name;
												final p = _progress[key] ?? 0.0;
												final st = _status[key] ?? '';
												final sizeMB = f.size > 0 ? (f.size / 1024 / 1024).toStringAsFixed(1) : '';
												return ListTile(
													tileColor: Colors.grey[100],
													shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
													title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
													subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
														if (sizeMB.isNotEmpty) Text('$sizeMB MB'),
														const SizedBox(height: 4),
														LinearProgressIndicator(value: p == 0.0 && st.isEmpty ? null : p),
														if (st.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(st, style: const TextStyle(fontSize: 12))),
													]),
													leading: const Icon(Icons.video_file_outlined),
												);
											},
										),
						),
						SizedBox(
							width: double.infinity,
							child: FilledButton.icon(
								onPressed: _loading || _files.isEmpty ? null : _startUpload,
								icon: const Icon(Icons.cloud_upload_outlined),
								label: Text(_loading ? 'Uploading…' : 'Start upload'),
							),
						),
					],
				),
			),
		);
	}
}

