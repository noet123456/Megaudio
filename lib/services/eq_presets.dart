import 'dart:convert';

/// Labels of the 10 EQ bands, low to high.
const List<String> kEqBandLabels = [
  '32Hz',
  '64Hz',
  '125Hz',
  '250Hz',
  '500Hz',
  '1kHz',
  '2kHz',
  '4kHz',
  '8kHz',
  '16kHz',
];

/// One EQ profile: a name plus a gain per band (dB, -12..12).
class EqPreset {
  final String name;
  final List<double> gains;
  final bool custom;

  const EqPreset({
    required this.name,
    required this.gains,
    this.custom = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'gains': gains,
      };

  /// Returns null when the stored entry is malformed.
  static EqPreset? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final gains = raw['gains'];
    if (name is! String || name.trim().isEmpty || gains is! List) return null;
    if (gains.length != kEqBandLabels.length) return null;
    final parsed = <double>[];
    for (final g in gains) {
      if (g is! num) return null;
      parsed.add(g.toDouble().clamp(-12.0, 12.0).toDouble());
    }
    return EqPreset(name: name.trim(), gains: parsed, custom: true);
  }
}

/// Built-in genre profiles. Values are tuned by ear: small, safe boosts so
/// they work on phone speakers as well as on a DAC.
const List<EqPreset> kBuiltinEqPresets = [
  EqPreset(name: 'Flat', gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  EqPreset(name: 'Rock', gains: [5, 4, 3, 1, -1, -1, 1, 3, 4, 5]),
  EqPreset(name: 'Pop', gains: [-1, -1, 0, 2, 4, 4, 2, 0, -1, -1]),
  EqPreset(name: 'Jazz', gains: [3, 2, 1, 2, -1, -1, 0, 1, 2, 3]),
  EqPreset(name: 'Classical', gains: [3, 2, 1, 0, -1, -1, 0, 1, 2, 3]),
  EqPreset(name: 'Hip-Hop', gains: [6, 5, 3, 1, -1, -2, 0, 2, 3, 4]),
  EqPreset(name: 'Electronic', gains: [6, 5, 2, 0, -1, 0, 1, 3, 5, 6]),
  EqPreset(name: 'Acoustic', gains: [2, 2, 1, 2, 2, 1, 2, 2, 1, 1]),
  EqPreset(name: 'Vocal', gains: [-2, -1, 0, 2, 3, 4, 3, 1, 0, -1]),
  EqPreset(name: 'Bass+', gains: [8, 7, 5, 2, 0, 0, 0, 0, 0, 0]),
  EqPreset(name: 'Treble+', gains: [0, 0, 0, 0, 0, 1, 3, 5, 7, 8]),
];

/// Encodes custom profiles for SharedPreferences.
String encodeEqPresets(List<EqPreset> presets) =>
    jsonEncode(presets.map((p) => p.toJson()).toList());

/// Decodes custom profiles, skipping malformed entries.
List<EqPreset> decodeEqPresets(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return list
        .map(EqPreset.fromJson)
        .whereType<EqPreset>()
        .toList(growable: true);
  } catch (_) {
    return const [];
  }
}

/// Encodes the current gain curve.
String encodeEqGains(List<double> gains) => jsonEncode(gains);

/// Decodes a saved gain curve; returns null when the value is unusable.
List<double>? decodeEqGains(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final list = jsonDecode(raw);
    if (list is! List || list.length != kEqBandLabels.length) return null;
    final gains = <double>[];
    for (final g in list) {
      if (g is! num) return null;
      gains.add(g.toDouble().clamp(-12.0, 12.0).toDouble());
    }
    return gains;
  } catch (_) {
    return null;
  }
}
