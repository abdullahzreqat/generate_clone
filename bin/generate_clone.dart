import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:generate_clone/src/constants/constants.dart';
import 'package:generate_clone/src/models/config_model.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

Future<void> main(List<String> arguments) async {
  try {
    final String filePath = arguments.isNotEmpty ? arguments[0] : '';
    if (filePath.isEmpty || !Directory(filePath).existsSync()) {
      throw Exception('Valid file path is required');
    }

    // Create temp directory
    await Directory(Constants.temp).create(recursive: true);

    // Extract the ZIP file
    //final configModel = await _extractAndHandleFiles(filePath);

    // Used for handle direct directory without zip
    final configModel = await _handleFilesFromDirectory(filePath);

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
  } catch (e) {
    print('Error: $e');
  }
}

//Deprecated Function
Future<String> _downloadFile(String clientId) async {
  // Define the base URL for the assets
  final String url =
      'https://fuel-pay.s3.eu-central-1.amazonaws.com/clones/$clientId/config.zip';

  // Define the file name
  final fileName = path.basename(url);

  // Send the request
  final response = await http.get(Uri.parse(url));

  // Check if the request was successful
  if (response.statusCode == 200) {
    await Directory(Constants.temp).create(recursive: true);

    // Save the file locally
    final String zipFilePath = path.join(Constants.temp, fileName);
    final File file = File(zipFilePath);
    await file.writeAsBytes(response.bodyBytes);

    print('Downloaded $fileName');
    return zipFilePath;
  } else {
    throw Exception('Failed to download $fileName: ${response.statusCode}');
  }
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
      final relativePath = path.relative(entity.path, from: directoryPath);
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

Future<ConfigModel?> _extractAndHandleFiles(String zipFilePath) async {
  // Read the ZIP file as bytes
  final bytes = await File(zipFilePath).readAsBytes();

  // Decode the ZIP file
  final archive = ZipDecoder().decodeBytes(bytes);
  ConfigModel? configModel;

  // Extract and handle splash images and assets
  for (final entity in archive) {
    final fileName = path.basename(entity.name);
    if (fileName.startsWith('.')) {
      continue;
    }
    // Create the correct file path
    String filePath = path.join(Constants.temp, fileName);

    if (entity.isFile) {
      if (entity.name.contains('assets/')) {
        // Handle assets directory files and move to lib/generated/cloneAssets/
        final assetFileName = path.basename(entity.name);
        final assetFilePath =
            path.join(Constants.cloneAssetsDirectory, assetFileName);

        await Directory(Constants.cloneAssetsDirectory).create(recursive: true);

        final outputFile = File(assetFilePath);
        await outputFile.create(recursive: true);
        await outputFile.writeAsBytes(entity.content);
        print('Extracted asset file: $assetFilePath');
      }
      // If the file is a splash image, move it to the correct directory
      else if (fileName == Constants.splash ||
          fileName == Constants.splashAndroid12 ||
          fileName == Constants.iconLauncher) {
        // Target directory for splash images
        await Directory(Constants.cloneDirectory).create(recursive: true);
        filePath = path.join(Constants.cloneDirectory, fileName);
        print('Moving splash image: $fileName to ${Constants.cloneDirectory}');
      } else if (fileName == Constants.configJson) {
        final json = jsonDecode(utf8.decode(entity.content));

        configModel = ConfigModel.fromJson(json);
      }

      // Write the file to disk
      final outputFile = File(filePath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsBytes(entity.content);
      print('Extracted file: $filePath');
    } else {
      // Handle other directories
      await Directory(filePath).create(recursive: true);
    }
  }

  print('Extraction and handling of files completed.');
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

  // 2. Create 'colors.dart' file
  final file = File('${directory.path}/clone_configs.dart');
  final sink = file.openWrite();

  // 3. Add 'CloneConfigs' class
  sink.writeln('// Auto-generated file. Do not edit manually.');
  sink.writeln("import 'package:flutter/material.dart';\n");
  sink.writeln('abstract class CloneConfigs {');

  for (var i = 0; i < (configModel.colors?.length ?? 0); i++) {
    final color = configModel.colors![i];
    sink.writeln('  static const ${color.name} = Color(0xFF${color.color});');
  }

  // 4. Add gradients
  for (var i = 0; i < (configModel.gradientsColors?.length ?? 0); i++) {
    final gradient = configModel.gradientsColors![i];
    sink.writeln('  static const ${gradient.name} = LinearGradient('
        'colors: <Color>['
        '${gradient.colors?.map((color) => 'Color(0xFF$color)').join(', ')}'
        '],'
        'begin: Alignment.${gradient.begin},'
        'end: Alignment.${gradient.end},'
        'transform: GradientRotation(${gradient.transform})'
        ');');
  }

  // 5. Add base url
  sink.writeln('  static const String baseUrl = "${configModel.baseUrl}";');

  // 6. Add chargingSocketUrl
  sink.writeln(
      '  static const String chargingSocketUrl = "${configModel.chargingSocketUrl}";');

  // 7. Add Clone ID
  sink.writeln('  static const String cloneId = "${configModel.cloneId}";');

  // 8. Add SSL Fingerprint
  if (configModel.sslFingerprint != null) {
    sink.writeln(
        '  static const String? sslFingerprint = "${configModel.sslFingerprint}";');
  } else {
    sink.writeln('  static const String? sslFingerprint = null;');
  }

  // 9. Access the _assetTargetDirectory and for each file in that directory add its path
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
  sink.close();

  print('Generated clone_configs.dart file.');
}

// ignore_for_file: avoid_print, missing_whitespace_between_adjacent_strings
