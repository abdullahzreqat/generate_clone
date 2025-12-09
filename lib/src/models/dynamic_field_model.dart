/// Represents a dynamic field with auto-detected type
class DynamicFieldModel {
  final String key;
  final dynamic value;
  final DynamicFieldType type;
  final bool isSensitive;
  final String? envKey; // Environment variable key for sensitive fields

  DynamicFieldModel({
    required this.key,
    required this.value,
    required this.type,
    this.isSensitive = false,
    this.envKey,
  });

  /// Parse a key-value pair and auto-detect the type
  /// Sensitive fields use format: "$ENV:ENV_VAR_NAME"
  factory DynamicFieldModel.fromEntry(String key, dynamic value) {
    // Check if it's a sensitive field (env var reference)
    if (value is String && value.startsWith(r'$ENV:')) {
      final envKey = value.substring(5); // Remove "$ENV:" prefix
      return DynamicFieldModel(
        key: key,
        value: value,
        type: DynamicFieldType.sensitive,
        isSensitive: true,
        envKey: envKey,
      );
    }

    final type = _detectType(value);
    return DynamicFieldModel(key: key, value: value, type: type);
  }

  static DynamicFieldType _detectType(dynamic value) {
    if (value == null) {
      return DynamicFieldType.nullValue;
    }

    if (value is bool) {
      return DynamicFieldType.bool;
    }

    if (value is int) {
      return DynamicFieldType.int;
    }

    if (value is double) {
      return DynamicFieldType.double;
    }

    if (value is String) {
      // Check if it's a color (hex format)
      if (_isColorHex(value)) {
        return DynamicFieldType.color;
      }
      return DynamicFieldType.string;
    }

    if (value is Map) {
      // Check if it's a gradient (has 'colors' array)
      if (value.containsKey('colors') && value['colors'] is List) {
        return DynamicFieldType.gradient;
      }
      return DynamicFieldType.map;
    }

    if (value is List) {
      // Check if it's a list of colors
      if (value.isNotEmpty && value.every((e) => e is String && _isColorHex(e))) {
        return DynamicFieldType.colorList;
      }
      return DynamicFieldType.list;
    }

    return DynamicFieldType.string;
  }

  /// Check if a string is a valid hex color
  static bool _isColorHex(String value) {
    // Supports: #RGB, #RRGGBB, #AARRGGBB, or without # prefix
    final hexPattern = RegExp(r'^#?([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$');
    return hexPattern.hasMatch(value.trim());
  }

  /// Convert hex color string to Flutter Color format (0xFFRRGGBB)
  static String colorToHex(String colorValue) {
    String hex = colorValue.replaceAll('#', '').toUpperCase();

    // Handle short format (#RGB -> #RRGGBB)
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }

    // Add alpha if not present (6 chars -> 8 chars)
    if (hex.length == 6) {
      hex = 'FF$hex';
    }

    return '0x$hex';
  }

  /// Generate Dart code for this field
  String toDartCode() {
    switch (type) {
      case DynamicFieldType.sensitive:
        // Sensitive fields use the resolver pattern
        return '  static String get $key => _resolve(\'$envKey\');';

      case DynamicFieldType.color:
        return '  static const $key = Color(${colorToHex(value as String)});';

      case DynamicFieldType.gradient:
        final map = value as Map;
        final colors = (map['colors'] as List)
            .map((c) => 'Color(${colorToHex(c.toString())})')
            .join(', ');
        final begin = map['begin'] ?? 'topLeft';
        final end = map['end'] ?? 'bottomRight';
        final transform = map['transform'] ?? 0.0;
        return '  static const $key = LinearGradient('
            'colors: <Color>[$colors], '
            'begin: Alignment.$begin, '
            'end: Alignment.$end, '
            'transform: GradientRotation($transform));';

      case DynamicFieldType.bool:
        return '  static const bool $key = $value;';

      case DynamicFieldType.int:
        return '  static const int $key = $value;';

      case DynamicFieldType.double:
        return '  static const double $key = $value;';

      case DynamicFieldType.string:
        return '  static const String $key = "$value";';

      case DynamicFieldType.colorList:
        final colors = (value as List)
            .map((c) => 'Color(${colorToHex(c.toString())})')
            .join(', ');
        return '  static const List<Color> $key = <Color>[$colors];';

      case DynamicFieldType.list:
        final items = (value as List).map((e) {
          if (e is String) return '"$e"';
          return e.toString();
        }).join(', ');
        return '  static const $key = [$items];';

      case DynamicFieldType.map:
        // For complex maps, store as JSON string
        return '  static const Map<String, dynamic> $key = $value;';

      case DynamicFieldType.nullValue:
        return '  static const $key = null;';
    }
  }
}

enum DynamicFieldType {
  string,
  int,
  double,
  bool,
  color,
  gradient,
  colorList,
  list,
  map,
  nullValue,
  sensitive,
}
