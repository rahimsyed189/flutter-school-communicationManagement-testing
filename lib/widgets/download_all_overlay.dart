import 'dart:ui';
import 'package:flutter/material.dart';

/// Center overlay for "Download all" with optional progress and a subtle blur.
class DownloadAllOverlay extends StatelessWidget {
	final bool isDownloading;
	final double? progress; // 0..1 when downloading; null => indeterminate
	final VoidCallback? onPressed;
	final String idleLabel; // default button label when not downloading
	final String? doneLabel; // optional label to show when progress == 1.0 (unused when parent hides)

		const DownloadAllOverlay({
		super.key,
		required this.isDownloading,
		required this.progress,
		required this.onPressed,
		this.idleLabel = 'Download',
		this.doneLabel,
	});

	@override
	Widget build(BuildContext context) {
		final pct = progress != null ? (progress!.clamp(0.0, 1.0)) : null;
		final isDone = pct != null && pct >= 1.0 - 1e-6;

		return InkWell(
			onTap: onPressed,
			borderRadius: BorderRadius.circular(16),
			child: ClipRRect(
				borderRadius: BorderRadius.circular(16),
				child: BackdropFilter(
					filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
					child: Container(
						padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
						decoration: BoxDecoration(
							gradient: LinearGradient(
								colors: [
									Colors.blue.withOpacity(0.7),
									Colors.purple.withOpacity(0.6),
								],
								begin: Alignment.topLeft,
								end: Alignment.bottomRight,
							),
							borderRadius: BorderRadius.circular(16),
							border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
							boxShadow: [
								BoxShadow(
									color: Colors.black.withOpacity(0.3),
									blurRadius: 8,
									offset: const Offset(0, 4),
								),
							],
						),
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								if (isDownloading)
									SizedBox(
										width: 24,
										height: 24,
										child: CircularProgressIndicator(
											strokeWidth: 3,
											value: pct,
											valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
											backgroundColor: Colors.white.withOpacity(0.3),
										),
									)
								else
									Container(
										padding: const EdgeInsets.all(2),
										decoration: BoxDecoration(
											color: Colors.white.withOpacity(0.2),
											borderRadius: BorderRadius.circular(6),
										),
										child: const Icon(
											Icons.download_for_offline,
											color: Colors.white,
											size: 20,
										),
									),
								const SizedBox(width: 12),
								Text(
									isDone
											? (doneLabel ?? '')
											: (isDownloading
													? (pct != null
															? 'Downloading ${(pct * 100).toStringAsFixed(0)}%'
															: 'Downloading…')
													: idleLabel),
									style: const TextStyle(
										color: Colors.white,
										fontWeight: FontWeight.bold,
										fontSize: 14,
										letterSpacing: 0.5,
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
