import 'package:flutter/material.dart';

/// Compatibility icon set.
///
/// The `lucide_icons` package is unmaintained and fails to compile on
/// Flutter >= 3.47 because `IconData` became a final class. This shim maps
/// every Lucide icon used in the app to its built-in Material counterpart.
class LucideIcons {
  LucideIcons._();

  static const IconData headphones = Icons.headphones;
  static const IconData sliders = Icons.tune;
  static const IconData folderPlus = Icons.create_new_folder;
  static const IconData sparkles = Icons.auto_awesome;
  static const IconData disc = Icons.album;
  static const IconData play = Icons.play_arrow;
  static const IconData pause = Icons.pause;
  static const IconData chevronDown = Icons.keyboard_arrow_down;
  static const IconData cpu = Icons.memory;
  static const IconData music = Icons.music_note;
  static const IconData shuffle = Icons.shuffle;
  static const IconData skipBack = Icons.skip_previous;
  static const IconData skipForward = Icons.skip_next;
  static const IconData repeat = Icons.repeat;
  static const IconData arrowLeft = Icons.arrow_back;
}
