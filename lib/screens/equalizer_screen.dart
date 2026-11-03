import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/player_provider.dart';
import '../services/audio_output_service.dart';
import '../services/eq_presets.dart';
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
  static const _prefEqGains = 'eq_gains_v1';
  static const _prefEqSelected = 'eq_selected_profile_v1';
  static const _prefEqCustom = 'eq_custom_profiles_v1';

  // 10-Band Equalizer Gains (dB from -12 to +12)
  List<double> _gains = List<double>.filled(kEqBandLabels.length, 0);
  final List<String> _bands = kEqBandLabels;

  bool _dsfOverSampling = true;
  bool _tubeHarmonicExciter = true;
  bool _spatialSurround = true;

  List<EqPreset> _customPresets = [];
  String? _selectedPreset = 'Flat';

  List<AudioOutputDevice> _outputs = const [];
  bool _loadingOutputs = false;

  @override
  void initState() {
    super.initState();
    _loadOutputs();
    _loadEq();
  }

  Future<void> _loadEq() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = decodeEqPresets(prefs.getString(_prefEqCustom));
    final gains = decodeEqGains(prefs.getString(_prefEqGains));
    final selected = prefs.getString(_prefEqSelected);
    if (!mounted) return;
    setState(() {
      _customPresets = custom;
      if (gains != null) _gains = gains;
      if (selected != null && _presetByName(selected) != null) {
        _selectedPreset = selected;
      }
    });
  }

  Future<void> _persistEq() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefEqGains, encodeEqGains(_gains));
    await prefs.setString(_prefEqCustom, encodeEqPresets(_customPresets));
    if (_selectedPreset == null) {
      await prefs.remove(_prefEqSelected);
    } else {
      await prefs.setString(_prefEqSelected, _selectedPreset!);
    }
  }

  EqPreset? _presetByName(String name) {
    for (final p in kBuiltinEqPresets) {
      if (p.name == name) return p;
    }
    for (final p in _customPresets) {
      if (p.name == name) return p;
    }
    return null;
  }

  void _applyPreset(EqPreset preset) {
    setState(() {
      _gains = List<double>.from(preset.gains);
      _selectedPreset = preset.name;
    });
    _persistEq();
  }

  void _onGainChanged(int index, double value) {
    setState(() {
      _gains[index] = value;
      // Any manual move makes the curve a custom one.
      _selectedPreset = null;
    });
  }

  Future<void> _promptSavePreset() async {
    final existing = _selectedPreset != null &&
        _customPresets.any((p) => p.name == _selectedPreset);
    final controller = TextEditingController(
      text: existing ? _selectedPreset : 'EQ của tôi',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: UiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: UiColors.line, width: 0.5),
        ),
        title: const Text(
          'LƯU EQ PROFILE',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: UiColors.text,
          ),
        ),
        content: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: UiColors.bg,
            border: Border.all(color: UiColors.line, width: 0.5),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune, size: 16, color: UiColors.textFaint),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13, color: UiColors.text),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Tên profile...',
                    hintStyle: TextStyle(fontSize: 12.5, color: UiColors.textFaint),
                  ),
                  onSubmitted: (v) => Navigator.pop(ctx, v),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'HỦY',
              style: TextStyle(fontSize: 10.5, letterSpacing: 1.5, color: UiColors.textDim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text(
              'LƯU',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: UiColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) {
      controller.dispose();
      return;
    }
    // Keep custom names distinct from the built-in ones.
    var finalName = trimmed;
    final clashesWithBuiltin = kBuiltinEqPresets.any(
      (p) => p.name.toLowerCase() == finalName.toLowerCase(),
    );
    final isExistingCustom = _customPresets.any(
      (p) => p.name.toLowerCase() == finalName.toLowerCase(),
    );
    if (clashesWithBuiltin && !isExistingCustom) {
      finalName = '$trimmed (của tôi)';
    }
    final index = _customPresets.indexWhere(
      (p) => p.name.toLowerCase() == finalName.toLowerCase(),
    );
    final preset = EqPreset(
      name: finalName,
      gains: List<double>.from(_gains),
      custom: true,
    );
    setState(() {
      if (index >= 0) {
        _customPresets[index] = preset;
      } else {
        _customPresets = [..._customPresets, preset];
      }
      _selectedPreset = preset.name;
    });
    controller.dispose();
    await _persistEq();
  }

  Future<void> _deletePreset(String name) async {
    setState(() {
      _customPresets = _customPresets.where((p) => p.name != name).toList();
      if (_selectedPreset == name) _selectedPreset = null;
    });
    await _persistEq();
  }

  Widget _presetChip(EqPreset preset) {
    final selected = _selectedPreset == preset.name;
    return GestureDetector(
      onTap: () => _applyPreset(preset),
      child: Container(
        padding: EdgeInsets.only(left: 12, right: preset.custom ? 4 : 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1FD8A657) : Colors.transparent,
          border: Border.all(
            color: selected ? UiColors.accent : UiColors.line,
            width: selected ? 0.9 : 0.5,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                preset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? UiColors.accent : UiColors.textDim,
                ),
              ),
            ),
            if (preset.custom)
              GestureDetector(
                onTap: () => _deletePreset(preset.name),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(Icons.close, size: 12, color: UiColors.textFaint),
                ),
              ),
          ],
        ),
      ),
    );
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
                'Bật "Chuyển DSD sang PCM" để nghe được file DSD trên mọi thiết bị.',
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

          _sectionLabel('DSD / DECODER'),

          // DSD conversion switch: on = universal playback, off = native DSD.
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
                        'Chuyển DSD sang PCM',
                        style: TextStyle(color: UiColors.text, fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Bật để nghe .dsf trên mọi thiết bị. Tắt để phát DSD gốc '
                        'khi máy hoặc DAC hỗ trợ giải mã DSD.',
                        style: TextStyle(color: UiColors.textFaint, fontSize: 11, height: 1.45),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: provider.dsdConvertEnabled,
                  onChanged: provider.setDsdConvertEnabled,
                  activeThumbColor: UiColors.accent,
                  inactiveThumbColor: UiColors.textFaint,
                  inactiveTrackColor: UiColors.line,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              provider.dsdConvertEnabled
                  ? 'Đang bật: file .dsf được chuyển thành WAV PCM 88.2kHz/16-bit '
                      'và lưu đệm cho lần phát sau.'
                  : 'Đang tắt: file .dsf được gửi trực tiếp tới thiết bị phát. '
                      'Nếu máy không hỗ trợ DSD, hãy bật lại tuỳ chọn này.',
              style: const TextStyle(fontSize: 10, color: UiColors.textFaint, height: 1.5),
            ),
          ),

          _sectionLabel('EQ PROFILE'),

          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_selectedPreset == null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x1FD8A657),
                        border: Border.all(color: UiColors.accent, width: 0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'Tùy chỉnh',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: UiColors.accent,
                        ),
                      ),
                    ),
                  ),
                for (final preset in [...kBuiltinEqPresets, ..._customPresets])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _presetChip(preset),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: _promptSavePreset,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: UiColors.accent, width: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 13, color: UiColors.accent),
                          SizedBox(width: 5),
                          Text(
                            'LƯU EQ',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                              color: UiColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Chọn profile có sẵn hoặc lưu dải tần hiện tại thành profile riêng. '
              'Nhấn × trên profile tự tạo để xoá.',
              style: TextStyle(fontSize: 10, color: UiColors.textFaint, height: 1.5),
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
                              onChanged: (val) => _onGainChanged(index, val),
                              onChangeEnd: (_) => _persistEq(),
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
