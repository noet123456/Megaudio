import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../services/audio_output_service.dart';
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

  List<AudioOutputDevice> _outputs = const [];
  bool _loadingOutputs = false;

  @override
  void initState() {
    super.initState();
    _loadOutputs();
  }

  Future<void> _loadOutputs() async {
    if (!AudioOutputService.isSupported) return;
    setState(() => _loadingOutputs = true);
    final list = await AudioOutputService.outputs();
    if (!mounted) return;
    setState(() {
      _outputs = list;
      _loadingOutputs = false;
    });
  }

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
          if (AudioOutputService.isSupported) ...[
            _sectionLabel('THIẾT BỊ RA ÂM THANH'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: UiColors.line, width: 0.5),
                  bottom: BorderSide(color: UiColors.line, width: 0.5),
                ),
              ),
              child: Column(
                children: [
                  if (_loadingOutputs)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: UiColors.textDim),
                        ),
                        SizedBox(width: 12),
                        Text('Đang đọc thiết bị...',
                            style: TextStyle(fontSize: 11, color: UiColors.textFaint)),
                      ],
                    )
                  else if (_outputs.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Không đọc được thiết bị ra.',
                          style: TextStyle(fontSize: 11, color: UiColors.textFaint)),
                    )
                  else
                    for (final device in _outputs)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              device.isDac
                                  ? Icons.usb
                                  : device.type == 'Bluetooth'
                                      ? Icons.bluetooth
                                      : Icons.headphones,
                              size: 18,
                              color: device.isDac ? UiColors.accent : UiColors.textFaint,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    device.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: UiColors.text),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    device.maxSampleRate > 0
                                        ? '${device.type} · ${(device.maxSampleRate / 1000).toStringAsFixed(1)} kHz'
                                        : device.type,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      color: UiColors.textFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (device.isDac)
                              const Text(
                                'DAC',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                  color: UiColors.accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                'Cắm DAC qua USB-C: Android tự định tuyến âm thanh sang DAC. '
                'File DSD vẫn cần giải mã phần mềm — Android không truyền DSD thô qua USB.',
                style: TextStyle(fontSize: 10, color: UiColors.textFaint, height: 1.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loadOutputs,
                  style: TextButton.styleFrom(
                    foregroundColor: UiColors.textDim,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('LÀM MỚI', style: TextStyle(fontSize: 10, letterSpacing: 1)),
                ),
              ),
            ),
          ],

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
