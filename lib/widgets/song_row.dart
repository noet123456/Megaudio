import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_colors.dart';
import '../widgets/cover_image.dart';

/// Shared flat song row (hairline bottom border) used across every list:
/// library views, genre/artist/album details, history.
class SongRow extends StatelessWidget {
  const SongRow({
    super.key,
    required this.song,
    required this.onTap,
    this.isPlaying = false,
    this.subtitle,
    this.trailing,
  });

  final Song song;
  final VoidCallback onTap;
  final bool isPlaying;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle ?? '${song.artist}  ·  ${song.specsLabel}';
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isPlaying ? UiColors.surface : Colors.transparent,
        child: Row(
          children: [
            CoverImage(path: song.coverPath, size: 48, radius: 3),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isPlaying ? UiColors.accent : UiColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: UiColors.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (song.isHiRes)
                      const Text(
                        'HI-RES',
                        style: TextStyle(
                          fontSize: 8.5,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                          color: UiColors.accent,
                        ),
                      ),
                    if (song.durationLabel.isNotEmpty)
                      Text(
                        song.durationLabel,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          color: UiColors.textFaint,
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

/// Small-caps section label ('NGHE GẦN ĐÂY', ...).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 8)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          color: UiColors.textFaint,
        ),
      ),
    );
  }
}

/// Flat app bar used by all sub-screens: small-caps centered title,
/// back arrow, hairline bottom edge.
AppBar flatAppBar(BuildContext context, String title, {List<Widget>? actions}) => AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 22, color: UiColors.text),
        onPressed: () => Navigator.maybePop(context),
      ),
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
          color: UiColors.text,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: actions,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(0.5),
        child: Divider(height: 0.5, thickness: 0.5, color: UiColors.line),
      ),
    );

/// 'X phút trước' style helper for history timestamps.
String timeAgoLabel(int epochMs) {
  final diff = DateTime.now().millisecondsSinceEpoch - epochMs;
  if (diff < 0) return '';
  final sec = diff ~/ 1000;
  if (sec < 60) return 'vừa xong';
  final min = sec ~/ 60;
  if (min < 60) return '$min phút trước';
  final hr = min ~/ 60;
  if (hr < 24) return '$hr giờ trước';
  final day = hr ~/ 24;
  if (day < 30) return '$day ngày trước';
  final month = day ~/ 30;
  if (month < 12) return '$month tháng trước';
  return '${month ~/ 12} năm trước';
}
