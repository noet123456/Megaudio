import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/player_provider.dart';
import 'screens/home_screen.dart';
import 'services/audio_handler.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On Android the media session lives in an audio_service handler: this is
  // what gives the app a compact media notification, lock-screen controls,
  // headset/Bluetooth buttons and makes the OS treat it as a music player.
  // Windows/web keep using a plain just_audio player.
  MegaudioAudioHandler? audioHandler;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    audioHandler = await AudioService.init(
      builder: () => MegaudioAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.noet123456.megaudio.audio',
        androidNotificationChannelName: 'Megaudio',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: false,
      ),
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider(audioHandler: audioHandler)),
      ],
      child: const MegaudioApp(),
    ),
  );
}

class MegaudioApp extends StatelessWidget {
  const MegaudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Megaudio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: UiColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: UiColors.accent,
          secondary: UiColors.accent,
          surface: UiColors.bg,
        ),
        // Flat app bars everywhere: same black canvas, no tint, no elevation.
        appBarTheme: const AppBarTheme(
          backgroundColor: UiColors.bg,
          foregroundColor: UiColors.text,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: UiColors.text, size: 22),
        ),
        iconTheme: const IconThemeData(color: UiColors.textDim),
        dividerColor: UiColors.line,
        fontFamily: 'sans-serif',
      ),
      home: const HomeScreen(),
    );
  }
}
