# generate_clone

**Stop struggling with Flutter flavors, build variants, and complex white-labeling setups.**

Tired of maintaining multiple `main_dev.dart`, `main_prod.dart`, `main_client1.dart` files? Frustrated with flavor configurations, build scripts, and environment variables scattered everywhere?

**generate_clone** is a simple CLI tool that generates fully configured Flutter app clones from a single JSON file. Perfect for:

- **White-label apps** - Create branded versions for multiple clients
- **Multi-tenant applications** - Deploy the same app with different configurations
- **App cloning services** - Automate client app generation
- **B2B SaaS products** - Customize apps for enterprise customers

## Why generate_clone?

| Traditional Approach | With generate_clone |
|---------------------|---------------------|
| Complex flavor setup | Single JSON config |
| Multiple main files | One command |
| Build variant headaches | Auto-generated constants |
| Manual asset copying | Automatic asset management |
| Environment variable chaos | Type-safe Dart code |

## Features

- **Flexible Input Sources**: Local directories, ZIP files, or remote URLs
- **Auto-Type Detection**: Colors, gradients, strings, ints, bools - all detected automatically
- **Sensitive Fields Support**: Use `$ENV:VAR_NAME` for API keys and secrets (works with flutter_dotenv, Platform.environment, etc.)
- **Auto Project Configuration**: Automatically updates `pubspec.yaml`, creates `flutter_launcher_icons.yaml` and `flutter_native_splash.yaml`
- **Latest Package Versions**: Fetches the latest versions of required packages from pub.dev
- **Complete Flutter Integration**: Runs `flutter_native_splash`, `flutter_launcher_icons`, and `rename` plugins
- **Asset Management**: Splash screens, icons, and custom assets organized automatically
- **Zero Configuration**: Just provide your config.json and run

## Installation

```bash
dart pub global activate generate_clone
```

Or add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  generate_clone: ^1.0.2
```

## Quick Start

```bash
# From a local directory
generate_clone ./my_client_config

# From a ZIP file
generate_clone ./client_branding.zip

# From a remote URL (CI/CD friendly)
generate_clone https://your-server.com/clients/acme/config.zip
```

## Configuration File (config.json)

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
    "analyticsUrl": "https://analytics.acme.com",
    "maxRetries": 3,
    "enableDarkMode": true,
    "taxRate": 0.15,
    "apiKey": "$ENV:API_KEY",
    "secretToken": "$ENV:SECRET_TOKEN"
  }
}
```

### Supported Field Types (Auto-Detected)

| Type | Example Value | Generated Dart Code |
|------|---------------|---------------------|
| Color | `"#FF5733"` | `Color(0xFFFF5733)` |
| Gradient | `{"colors": [...], ...}` | `LinearGradient(...)` |
| String | `"https://example.com"` | `String` |
| int | `3` | `int` |
| double | `0.15` | `double` |
| bool | `true` | `bool` |
| Sensitive | `"$ENV:API_KEY"` | `String get apiKey => _resolve('API_KEY')` |

### Sensitive Fields (Environment Variables)

For API keys, secrets, and other sensitive data, use the `$ENV:` prefix. This generates code with a resolver pattern that you initialize once in `main.dart`:

```dart
// With flutter_dotenv
await dotenv.load();
CloneConfigs.init((key) => dotenv.env[key] ?? '');

// With Platform.environment
CloneConfigs.init((key) => Platform.environment[key] ?? '');

// With your custom solution
CloneConfigs.init((key) => MySecretManager.get(key));
```

> **Note:** If your config.json doesn't contain any `$ENV:` fields, the generated code won't include the resolver pattern and you don't need to call `CloneConfigs.init()`.

For a complete example, check out the [example](example/example.md) file.

## Input Directory Structure

```
client_config/
├── config.json           # Required: Configuration
├── splash.png            # Optional: Splash screen
├── splashAndroid12.png   # Optional: Android 12+ splash
├── ic_launcher.png       # Optional: App icon
└── assets/               # Optional: Custom assets
    ├── logo.png
    └── background.png
```

## Generated Output

Type-safe, auto-generated `lib/generated/clone/clone_configs.dart`:

```dart
// Auto-generated file. Do not edit manually.
import 'package:flutter/material.dart';

abstract class CloneConfigs {
  // Resolver for sensitive fields (only if $ENV: fields exist)
  static String Function(String key)? _envResolver;
  static void init(String Function(String key) resolver) => _envResolver = resolver;
  static String _resolve(String key) => _envResolver!(key);

  // Fixed configuration
  static const String baseUrl = "https://api.acme.com/v1";
  static const String cloneId = "acme";

  // Dynamic configuration
  static const kPrimaryColor = Color(0xFFFF5733);
  static const kSecondaryColor = Color(0xFF3498DB);
  static const kPrimaryGradient = LinearGradient(...);
  static const String analyticsUrl = "https://analytics.acme.com";
  static const int maxRetries = 3;
  static const bool enableDarkMode = true;
  static const double taxRate = 0.15;

  // Sensitive fields
  static String get apiKey => _resolve('API_KEY');
  static String get secretToken => _resolve('SECRET_TOKEN');
}
```

## Use Cases

- **Agencies**: Generate branded apps for multiple clients from a single codebase
- **SaaS Companies**: Deploy customized versions for enterprise customers
- **Franchises**: Create location-specific apps with unique branding
- **Startups**: Quickly spin up MVPs with different configurations

## Keywords

`white-label` `whitelabel` `multi-tenant` `clone` `flutter-clone` `app-generator` `branding` `flavors-alternative` `build-variants` `b2b` `saas` `enterprise` `customization`

## License

BSD 3-Clause License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on [GitHub](https://github.com/abdullahzreqat/generate_clone).