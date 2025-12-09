import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:generate_clone/src/constants/constants.dart';
import 'package:generate_clone/src/models/config_model.dart';
import 'package:generate_clone/src/models/input_source.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

Future<void> main(List<String> arguments) async {
  try {
    final String input = arguments.isNotEmpty ? arguments[0] : '';
    if (input.isEmpty) {
      throw Exception('Input path or URL is required');
    }

    // Detect input type (local directory, local ZIP, or remote URL)
    final inputSource = InputSource.detect(input);
    print('Detected input: $inputSource');

    // Create temp directory
    await Directory(Constants.temp).create(recursive: true);

    // Process input based on type
    final configModel = await _processInput(inputSource);

    if (configModel != null && configModel.isValid) {
      await _generateCloneConfigFile(configModel);

      // Run rename package command
      await _runRenamePackage(
        appName: configModel.appName!,
        packageName: configModel.packageName!,
      );
    }
    // Run the flutter_native_splash command
    await _runFlutterNativeSplash();
    // Run flutter_launcher_icons command
    await _runFlutterIconLauncher();
    // Remove the temp directory
    await Directory(Constants.temp).delete(recursive: true);

    print('Clone generation completed successfully!');
  } catch (e) {
    print('Error: $e');
  }
}

/// Unified input processor - handles all input types
Future<ConfigModel?> _processInput(InputSource source) async {
  switch (source.type) {
    case InputType.localDirectory:
      print('Processing local directory: ${source.path}');
      return _handleFilesFromDirectory(source.path);

    case InputType.localZip:
      print('Processing local ZIP file: ${source.path}');
      return _extractAndHandleZipFile(source.path);

    case InputType.remoteUrl:
      print('Downloading from URL: ${source.path}');
      final localPath = await _downloadFromUrl(source.path);

      // Check if downloaded file is a ZIP or directory
      if (source.isCompressed) {
        return _extractAndHandleZipFile(localPath);
      } else {
        // For non-compressed URLs, we expect the download to be a directory
        // or we need to handle it as raw files
        return _handleFilesFromDirectory(localPath);
      }
  }
}

/// Download file from URL and return local path
Future<String> _downloadFromUrl(String url) async {
  final fileName = path.basename(Uri.parse(url).path);
  final isZip = fileName.toLowerCase().endsWith('.zip');

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final String localPath = path.join(Constants.temp, fileName);
    final File file = File(localPath);
    await file.writeAsBytes(response.bodyBytes);
    print('Downloaded: $fileName');

    // If it's a ZIP, extract it to a subdirectory
    if (isZip) {
      return localPath;
    }

    return localPath;
  } else {
    throw Exception('Failed to download from $url: ${response.statusCode}');
  }
}

/// Extract ZIP file and process contents
Future<ConfigModel?> _extractAndHandleZipFile(String zipFilePath) async {
  final bytes = await File(zipFilePath).readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);

  // Extract to temp directory first
  final extractDir = path.join(Constants.temp, 'extracted');
  await Directory(extractDir).create(recursive: true);

  for (final entity in archive) {
    final fileName = entity.name;
    if (path.basename(fileName).startsWith('.')) continue;

    final filePath = path.join(extractDir, fileName);

    if (entity.isFile) {
      final outputFile = File(filePath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsBytes(entity.content);
    } else {
      await Directory(filePath).create(recursive: true);
    }
  }

  print('Extracted ZIP to: $extractDir');

  // Now process the extracted directory
  return _handleFilesFromDirectory(extractDir);
}

Future<ConfigModel?> _handleFilesFromDirectory(String directoryPath) async {
  final directory = Directory(directoryPath);
  if (!await directory.exists()) {
    print('Directory does not exist: $directoryPath');
    return null;
  }

  ConfigModel? configModel;

  await for (var entity in directory.list(recursive: true)) {
    if (entity is File) {
      final fileName = path.basename(entity.path);

      if (fileName.startsWith('.')) continue;

      String filePath = path.join(Constants.temp, fileName);

      // Read file content
      final content = await entity.readAsBytes();

      if (entity.path.contains('assets${Platform.pathSeparator}')) {
        // Handle assets directory files
        final assetFileName = path.basename(entity.path);
        final assetFilePath =
            path.join(Constants.cloneAssetsDirectory, assetFileName);

        await Directory(Constants.cloneAssetsDirectory).create(recursive: true);
        final outputFile = File(assetFilePath);
        await outputFile.create(recursive: true);
        await outputFile.writeAsBytes(content);
        print('Copied asset file: $assetFilePath');
      } else if (fileName == Constants.splash ||
          fileName == Constants.splashAndroid12 ||
          fileName == Constants.iconLauncher) {
        await Directory(Constants.cloneDirectory).create(recursive: true);
        filePath = path.join(Constants.cloneDirectory, fileName);
        print('Copying splash image: $fileName to ${Constants.cloneDirectory}');
      } else if (fileName == Constants.configJson) {
        final json = jsonDecode(utf8.decode(content));
        configModel = ConfigModel.fromJson(json);
      }

      final outputFile = File(filePath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsBytes(content);
      print('Copied file: $filePath');
    } else if (entity is Directory) {
      // Optionally recreate directory structure
      final dirPath = path.join(
          Constants.temp, path.relative(entity.path, from: directoryPath));
      await Directory(dirPath).create(recursive: true);
    }
  }

  print('Handling of directory files completed.');
  return configModel;
}

// Helper function to run a command
Future<void> _runCommand(String command, List<String> args,
    String successMessage, String errorMessage) async {
  final ProcessResult result = await Process.run(command, args);
  if (result.exitCode == 0) {
    print(successMessage);
  } else {
    throw Exception('$errorMessage: ${result.stderr}');
  }
}

Future<void> _runFlutterNativeSplash() async {
  await _runCommand(
      'flutter',
      ['pub', 'run', 'flutter_native_splash:create'],
      "Successfully ran flutter_native_splash",
      "Error running flutter_native_splash");
}

Future<void> _runFlutterIconLauncher() async {
  await _runCommand(
      'flutter',
      ['pub', 'run', 'flutter_launcher_icons'],
      "Successfully ran flutter_launcher_icons",
      "Error running flutter_launcher_icons");
}

Future<void> _runRenamePackage({
  required String appName,
  required String packageName,
}) async {
  // Activate the plugin
  await _runCommand(
    'dart',
    ['pub', 'global', 'activate', 'rename'],
    'Successfully activated rename',
    'Error activating rename',
  );

  // Set the app name
  await _runCommand(
    'flutter',
    ['pub', 'run', 'rename', 'setAppName', '-t', 'ios,android', '-v', appName],
    'Successfully set the app name to $appName',
    'Error setting app name',
  );

  // Set the package name
  await _runCommand(
    'flutter',
    [
      'pub',
      'run',
      'rename',
      'setBundleId',
      '-t',
      'ios,android',
      '-v',
      packageName
    ],
    'Successfully set the package name to $packageName',
    'Error setting package name',
  );
}

Future<void> _generateCloneConfigFile(ConfigModel configModel) async {
  // 1. Check if the 'generated' directory exists
  final directory = Directory(Constants.cloneDirectory);
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
    print('Created "lib/generated" directory.');
  }

  // 2. Create config file
  final file = File('${directory.path}/clone_configs.dart');
  final sink = file.openWrite();

  // 3. Add 'CloneConfigs' class
  sink.writeln('// Auto-generated file. Do not edit manually.');
  sink.writeln("import 'package:flutter/material.dart';\n");
  sink.writeln('abstract class CloneConfigs {');

  // 4. Add fixed fields
  sink.writeln('  static const String baseUrl = "${configModel.baseUrl}";');
  sink.writeln('  static const String cloneId = "${configModel.cloneId}";');

  // 5. Add dynamic fields
  for (final field in configModel.fields) {
    sink.writeln(field.toDartCode());
  }

  // 6. Access the _assetTargetDirectory and for each file in that directory add its path
  final assetsDirectory = Directory(Constants.cloneAssetsDirectory);

  if (assetsDirectory.existsSync()) {
    final assetFiles = assetsDirectory.listSync();
    for (final asset in assetFiles) {
      if (asset is File) {
        final assetFileName = path.basename(asset.path);
        final variableName = path.withoutExtension(assetFileName).replaceAll(
            RegExp(r'\W+'), '_'); // Sanitize file names to valid variable names
        sink.writeln(
            '  static const String $variableName = "${Constants.cloneAssetsDirectory}$assetFileName";');
      }
    }
  }

  sink.writeln('}');

  // Close the file stream
  await sink.close();

  print('Generated clone_configs.dart file.');
}

// ignore_for_file: avoid_print, missing_whitespace_between_adjacent_strings
