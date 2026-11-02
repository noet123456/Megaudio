import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../utils/app_icons.dart';

/// Flat, monochrome DSP / EQ settings page in the Walkman language:
/// black canvas, hairline separators, section labels in small caps,
/// amber reserved for active switches and active slider tracks.
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  // 10-Band Equalizer Gains (dB from -12 to +12)
  final List<double> _gains = [0.0, 2.5, 4.0, 1.5, -1.0, 2.0, 3.5, 5.0, 4.5, 3.0];
  final List<String> _bands = ['32Hz', '64Hz', '125Hz', '250Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'];

  bool _dsfOverSampling = true;
  bool _tubeHarmonicExciter = true;
  bool _spatialSurround = true;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);

    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 22, color: UiColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'DSP / EQUALIZER',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
            color: UiColors.text,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, thickness: 0.5, color: UiColors.line),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _sectionLabel('CUSTOM DECODER'),

          // Custom DSP engine toggle.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: UiColors.line, width: 0.5),
                bottom: BorderSide(color: UiColors.line, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom DSD-to-PCM FIR Filter',
                        style: TextStyle(color: UiColors.text, fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Bộ giải mã nhị phân tự viết cho file Hi-Res',
                        style: TextStyle(color: UiColors.textFaint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: provider.isCustomDspEnabled,
                  onChanged: (_) => provider.toggleCustomDsp(),
                  activeThumbColor: UiColors.accent,
                  inactiveThumbColor: UiColors.textFaint,
                  inactiveTrackColor: UiColors.line,
                ),
              ],
            ),
          ),

          _sectionLabel('10-BAND PARAMETRIC EQ'),

          // EQ sliders: flat band with hairlines top and bottom.
          SizedBox(
            height: 224,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _bands.length,
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_gains[index].toStringAsFixed(1)}dB',
                        style: const TextStyle(
                          color: UiColors.textDim,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: SliderTheme(
                          data: const SliderThemeData(
                            trackHeight: 2,
                            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 3),
                            overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                            activeTrackColor: UiColors.accent,
                            inactiveTrackColor: UiColors.line,
                            thumbColor: UiColors.textDim,
                            overlayColor: Color(0x22D8A657),
                          ),
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: _gains[index],
                              min: -12.0,
                              max: 12.0,
                              onChanged: (val) {
                                setState(() {
                                  _gains[index] = val;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _bands[index],
                        style: const TextStyle(
                          color: UiColors.textFaint,
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5, color: UiColors.line),

          _sectionLabel('DSP ENHANCEMENTS'),

          _toggleRow(
            'DSD Oversampling (2x / 4x)',
            'Giảm nhiễu lượng tử trong file 1-bit DSF',
            _dsfOverSampling,
            (val) => setState(() => _dsfOverSampling = val),
          ),
          _toggleRow(
            'Tube Harmonic Exciter',
            'Thêm màu âm analog ấm cho bản thu số',
            _tubeHarmonicExciter,
            (val) => setState(() => _tubeHarmonicExciter = val),
          ),
          _toggleRow(
            'Spatial 3D Headphone Surround',
            'Mở rộng trường âm và tách bạch nhạc cụ',
            _spatialSurround,
            (val) => setState(() => _spatialSurround = val),
          ),
          _toggleRow(
            'Hiển thị phổ âm (Spectrum)',
            'Bật/tắt thanh phổ âm động trên màn hình phát nhạc',
            provider.showSpectrum,
            (_) => provider.toggleSpectrum(),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
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

  Widget _toggleRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: UiColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: UiColors.text, fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: UiColors.textFaint, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: UiColors.accent,
            inactiveThumbColor: UiColors.textFaint,
            inactiveTrackColor: UiColors.line,
          ),
        ],
      ),
    );
  }
}
