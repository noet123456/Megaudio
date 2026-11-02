import 'dart:math';

import 'package:flutter/material.dart';

/// Animated audio spectrum bars visualizer.
/// Drives smooth pseudo-random band levels; freezes and decays to the baseline
/// when playback is paused. Toggle it from the player screen (graphic_eq icon).
class SpectrumVisualizer extends StatefulWidget {
  const SpectrumVisualizer({
    super.key,
    this.barCount = 32,
    this.isPlaying = false,
    this.height = 96,
  });

  final int barCount;
  final bool isPlaying;
  final double height;

  @override
  State<SpectrumVisualizer> createState() => _SpectrumVisualizerState();
}

class _SpectrumVisualizerState extends State<SpectrumVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Stopwatch _stopwatch;
  late final List<double> _levels;
  late final List<double> _speed1;
  late final List<double> _speed2;
  late final List<double> _phase1;
  late final List<double> _phase2;
  final Random _rng = Random(1337);

  @override
  void initState() {
    super.initState();
    final n = widget.barCount;
    _levels = List.filled(n, 0.04);
    _speed1 = List.generate(n, (_) => 1.2 + _rng.nextDouble() * 2.8);
    _speed2 = List.generate(n, (_) => 2.5 + _rng.nextDouble() * 4.5);
    _phase1 = List.generate(n, (_) => _rng.nextDouble() * pi * 2);
    _phase2 = List.generate(n, (_) => _rng.nextDouble() * pi * 2);
    _stopwatch = Stopwatch()..start();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 33),
    )
      ..repeat()
      ..addListener(_tick);
  }

  void _tick() {
    final t = _stopwatch.elapsedMicroseconds / 1e6;
    final n = widget.barCount;
    final playing = widget.isPlaying;
    for (var i = 0; i < n; i++) {
      final x = i / max(1, n - 1);
      final wave =
          (sin(t * _speed1[i] + _phase1[i]) * 0.65 + sin(t * _speed2[i] + _phase2[i]) * 0.35).abs();
      double target = playing ? 0.12 + 0.88 * wave : 0.04;
      target *= 1.0 - 0.45 * x; // spectrum-like energy tilt
      _levels[i] += (target - _levels[i]) * (playing ? 0.28 : 0.06);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SpectrumPainter(levels: _levels, repaint: _controller),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({required this.levels, required Listenable repaint})
      : super(repaint: repaint);

  final List<double> levels;

  @override
  void paint(Canvas canvas, Size size) {
    final n = levels.length;
    if (n == 0 || size.width <= 0) return;
    final slot = size.width / n;
    final barWidth = (slot * 0.5).clamp(2.0, 4.0);
    const radius = Radius.circular(1.5);

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF6E5322), Color(0xFFD8A657)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var i = 0; i < n; i++) {
      final h = max(3.0, levels[i] * size.height);
      final left = slot * i + (slot - barWidth) / 2;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - h, barWidth, h),
        radius,
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
