import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../widgets/mini_player_bar.dart';
import 'equalizer_screen.dart';
import 'offline_home_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);

    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: AppBar(
        // App logo: opens the side menu.
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.album, size: 26, color: UiColors.accent),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        // No title: the bar keeps only the logo and the quick actions.
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 21),
            onPressed: () => provider.rescanFolder(),
            tooltip: 'Quét lại thư mục',
          ),
          IconButton(
            icon: const Icon(Icons.tune, size: 21),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EqualizerScreen()));
            },
            tooltip: 'Equalizer / DSP',
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined, size: 21),
            onPressed: () => provider.pickMusicFolder(),
            tooltip: 'Chọn thư mục nhạc',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, thickness: 0.5, color: UiColors.line),
        ),
      ),
      drawer: const AppDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.errorMessage != null) _ErrorBanner(provider: provider),
          if (provider.musicFolderPath != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                provider.musicFolderPath!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: UiColors.textFaint,
                ),
              ),
            ),
          const Expanded(child: OfflineHomeView()),
          const MiniPlayerBar(),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.provider});

  final PlayerProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: UiColors.surface,
        border: Border.all(color: UiColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: UiColors.accent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(color: UiColors.textDim, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: UiColors.textFaint, size: 15),
            onPressed: provider.clearError,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
