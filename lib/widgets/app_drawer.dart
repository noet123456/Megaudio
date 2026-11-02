import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../screens/collection_screens.dart';
import '../screens/equalizer_screen.dart';
import '../screens/extra_screens.dart';

/// Left slide-out menu, opened from the app logo.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    return Drawer(
      backgroundColor: UiColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        right: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header: logo + app name
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.album, size: 22, color: UiColors.accent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MEGAUDIO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.5,
                            color: UiColors.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'OFFLINE · HI-RES LIBRARY',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.5,
                            color: UiColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 0.5, thickness: 0.5, color: UiColors.line),

            _item(
              context,
              icon: Icons.search,
              label: 'Tìm kiếm nhạc',
              onTap: () => _push(context, const AllSongsScreen(search: true)),
            ),
            _item(
              context,
              icon: Icons.history,
              label: 'Nghe gần đây',
              onTap: () => _push(context, const RecentScreen()),
            ),
            _item(
              context,
              icon: Icons.schedule,
              label: 'Lâu chưa nghe',
              onTap: () => _push(context, const ForgottenScreen()),
            ),
            const Divider(height: 0.5, thickness: 0.5, color: UiColors.line),
            _item(
              context,
              icon: Icons.create_new_folder_outlined,
              label: 'Chọn thư mục nhạc',
              onTap: () {
                Navigator.pop(context);
                provider.pickMusicFolder();
              },
            ),
            _item(
              context,
              icon: Icons.refresh,
              label: 'Quét lại thư mục',
              onTap: () {
                Navigator.pop(context);
                provider.rescanFolder();
              },
            ),
            _item(
              context,
              icon: Icons.tune,
              label: 'DSP / Equalizer',
              onTap: () => _push(context, const EqualizerScreen()),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Local Hi-Res engine · FLAC / WAV / DSF / MP3',
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: UiColors.textFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context); // close the drawer first
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: UiColors.line, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: UiColors.textDim),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: UiColors.text),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: UiColors.textFaint),
          ],
        ),
      ),
    );
  }
}
