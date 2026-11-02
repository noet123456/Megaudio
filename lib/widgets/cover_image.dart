import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_icons.dart';
import '../utils/io_facade.dart';

/// Small square album cover used in lists and the mini player.
/// Uses the embedded artwork file for offline tracks and falls back to a
/// quiet dark tile when no artwork is available.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.path,
    this.size = 48,
    this.radius = 3,
  });

  final String path;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Widget inner =
        (path.isNotEmpty ? localCoverImage(path, fit: BoxFit.cover, cacheWidth: 128) : null) ??
            _fallbackTile();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: inner),
    );
  }

  Widget _fallbackTile() => Container(
        color: UiColors.surface,
        child: Center(
          child: Icon(LucideIcons.music, size: size * 0.42, color: UiColors.textFaint),
        ),
      );
}
