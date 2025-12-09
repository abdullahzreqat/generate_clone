# generate_clone Example

## Step 1: Create Your Config Directory

```
my_client_config/
├── config.json
├── splash.png
├── splashAndroid12.png
├── ic_launcher.png
└── assets/
    └── logo.png
```

## Step 2: Create config.json

```json
{
  "appName": "Acme Corp",
  "packageName": "com.acme.app",
  "baseUrl": "https://api.acme.com/v1",
  "cloneId": "acme",

  "fields": {
    "kPrimaryColor": "#FF5733",
    "kSecondaryColor": "#3498DB",
    "kPrimaryGradient": {
      "colors": ["#FF5733", "#FFC300"],
      "begin": "topLeft",
      "end": "bottomRight"
    },
    "maxRetries": 3,
    "enableDarkMode": true,
    "taxRate": 0.15,
    "apiKey": "$ENV:API_KEY",
    "secretToken": "$ENV:SECRET_TOKEN"
  }
}
```

## Step 3: Run generate_clone

```bash
# From local directory
generate_clone ./my_client_config

# From ZIP file
generate_clone ./my_client_config.zip

# From remote URL
generate_clone https://your-server.com/configs/acme.zip
```

## Step 4: Initialize in main.dart (Only if using $ENV: fields)

> **Note:** This step is only required if your config.json contains sensitive fields with `$ENV:` prefix. If you don't have any `$ENV:` fields, skip this step.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lib/generated/clone/clone_configs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  // Only needed if you have $ENV: fields in config.json
  CloneConfigs.init((key) => dotenv.env[key] ?? '');

  runApp(const MyApp());
}
```

## Step 5: Use Generated Configs

```dart
import 'lib/generated/clone/clone_configs.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: CloneConfigs.kPrimaryColor,
      ),
      home: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: CloneConfigs.kPrimaryGradient,
            ),
          ),
        ),
        body: Column(
          children: [
            Image.asset(CloneConfigs.logo),
            Text('Clone: ${CloneConfigs.cloneId}'),
            Text('Dark Mode: ${CloneConfigs.enableDarkMode}'),
            Text('Tax Rate: ${CloneConfigs.taxRate}'),
            // Sensitive fields (only if using $ENV:)
            Text('API Key: ${CloneConfigs.apiKey}'),
          ],
        ),
      ),
    );
  }
}
```

## Generated Output

### With $ENV: fields (resolver included):

```dart
abstract class CloneConfigs {
  static String Function(String key)? _envResolver;

  static void init(String Function(String key) resolver) {
    _envResolver = resolver;
  }

  // Fixed configuration
  static const String baseUrl = "https://api.acme.com/v1";
  static const String cloneId = "acme";

  // Dynamic configuration
  static const kPrimaryColor = Color(0xFFFF5733);
  static const int maxRetries = 3;

  // Sensitive fields
  static String get apiKey => _resolve('API_KEY');
}
```

### Without $ENV: fields (no resolver):

```dart
abstract class CloneConfigs {
  // Fixed configuration
  static const String baseUrl = "https://api.acme.com/v1";
  static const String cloneId = "acme";

  // Dynamic configuration
  static const kPrimaryColor = Color(0xFFFF5733);
  static const int maxRetries = 3;
}
```

## Supported Field Types

| JSON Value | Generated Dart Code |
|------------|---------------------|
| `"#FF5733"` | `Color(0xFFFF5733)` |
| `{"colors": [...], "begin": "topLeft", "end": "bottomRight"}` | `LinearGradient(...)` |
| `"string"` | `String` |
| `123` | `int` |
| `0.15` | `double` |
| `true` | `bool` |
| `"$ENV:VAR_NAME"` | `String get varName => _resolve('VAR_NAME')` |