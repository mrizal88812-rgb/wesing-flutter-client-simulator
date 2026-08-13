class AudioPreset {
  final String id;
  final String name;
  final String description;
  final String icon; // Can be a local asset name, or we can use gradients in UI
  final DspConfig? dsp; // Nullable for 'Adjust' button or if just listing
  final String schemaVersion; // schema version field

  AudioPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.dsp,
    this.schemaVersion = '1.0.0',
  });

  factory AudioPreset.fromJson(Map<String, dynamic> json) {
    // Schema validation and required fields checks
    if (json['id'] == null || json['id'] is! String || (json['id'] as String).trim().isEmpty) {
      throw const FormatException('[AudioPreset] Invalid or missing Preset ID');
    }
    if (json['name'] == null || json['name'] is! String || (json['name'] as String).trim().isEmpty) {
      throw const FormatException('[AudioPreset] Invalid or missing Preset Name');
    }

    final schemaVer = json['version']?.toString() ?? '1.0.0';

    return AudioPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      dsp: json['dsp'] != null ? DspConfig.fromJson(json['dsp']) : null,
      schemaVersion: schemaVer,
    );
  }
}

class DspConfig {
  final double reverb;
  final double delay;
  final double echo;
  final double vocalGain;
  final double compressor;
  final double limiter;
  final double noiseReduction;
  final double eqLow;
  final double eqMid;
  final double eqHigh;
  final double stereoWidth;
  final double presence;
  final double brightness;

  DspConfig({
    required this.reverb,
    required this.delay,
    required this.echo,
    required this.vocalGain,
    required this.compressor,
    required this.limiter,
    required this.noiseReduction,
    required this.eqLow,
    required this.eqMid,
    required this.eqHigh,
    required this.stereoWidth,
    required this.presence,
    required this.brightness,
  });

  factory DspConfig.fromJson(Map<String, dynamic> json) {
    // Defensive clamping to prevent digital clipping / distortion or invalid DSP settings
    double clamp(double val, double min, double max) {
      if (val.isNaN) return min;
      return val.clamp(min, max);
    }

    return DspConfig(
      reverb: clamp((json['reverb'] ?? 0.0).toDouble(), 0.0, 1.0),
      delay: clamp((json['delay'] ?? 0.0).toDouble(), 0.0, 1.0),
      echo: clamp((json['echo'] ?? 0.0).toDouble(), 0.0, 1.0),
      vocalGain: clamp((json['vocalGain'] ?? 1.0).toDouble(), 0.0, 2.0),
      compressor: clamp((json['compressor'] ?? 0.0).toDouble(), 0.0, 1.0),
      limiter: clamp((json['limiter'] ?? 0.0).toDouble(), 0.0, 1.0),
      noiseReduction: clamp((json['noiseReduction'] ?? 0.0).toDouble(), 0.0, 1.0),
      eqLow: clamp((json['eqLow'] ?? 0.0).toDouble(), -1.0, 1.0),
      eqMid: clamp((json['eqMid'] ?? 0.0).toDouble(), -1.0, 1.0),
      eqHigh: clamp((json['eqHigh'] ?? 0.0).toDouble(), -1.0, 1.0),
      stereoWidth: clamp((json['stereoWidth'] ?? 0.0).toDouble(), 0.0, 1.0),
      presence: clamp((json['presence'] ?? 0.0).toDouble(), 0.0, 1.0),
      brightness: clamp((json['brightness'] ?? 0.0).toDouble(), 0.0, 1.0),
    );
  }
}
