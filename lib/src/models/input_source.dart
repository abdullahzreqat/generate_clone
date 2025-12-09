import 'dart:io';

/// Represents the type of input source
enum InputType {
  localDirectory,
  localZip,
  remoteUrl,
}

/// Represents the compression type of a file
enum CompressionType {
  none,
  zip,
}

/// Model to detect and handle different input sources
class InputSource {
  final String path;
  final InputType type;
  final CompressionType compression;

  InputSource._({
    required this.path,
    required this.type,
    required this.compression,
  });

  /// Factory to detect input type from a path string
  factory InputSource.detect(String input) {
    final trimmed = input.trim();

    // Check if it's a URL
    if (_isUrl(trimmed)) {
      final compression = _detectCompressionFromPath(trimmed);
      return InputSource._(
        path: trimmed,
        type: InputType.remoteUrl,
        compression: compression,
      );
    }

    // Check if it's a local path
    if (Directory(trimmed).existsSync()) {
      return InputSource._(
        path: trimmed,
        type: InputType.localDirectory,
        compression: CompressionType.none,
      );
    }

    if (File(trimmed).existsSync()) {
      final lowerPath = trimmed.toLowerCase();
      if (lowerPath.endsWith('.zip')) {
        return InputSource._(
          path: trimmed,
          type: InputType.localZip,
          compression: CompressionType.zip,
        );
      }
    }

    // Default: treat as path (might not exist yet)
    throw ArgumentError('Input path does not exist or is not supported: $input');
  }

  /// Check if a string is a URL
  static bool _isUrl(String input) {
    return input.startsWith('http://') || input.startsWith('https://');
  }

  /// Detect compression type from file path/URL
  static CompressionType _detectCompressionFromPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.zip')) {
      return CompressionType.zip;
    }
    return CompressionType.none;
  }

  bool get isLocal => type == InputType.localDirectory ||
                       type == InputType.localZip;

  bool get isRemote => type == InputType.remoteUrl;

  bool get isCompressed => compression != CompressionType.none;

  bool get isDirectory => type == InputType.localDirectory;

  @override
  String toString() {
    return 'InputSource(path: $path, type: $type, compression: $compression)';
  }
}
