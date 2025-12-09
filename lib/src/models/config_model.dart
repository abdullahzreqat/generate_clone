import 'package:generate_clone/src/models/dynamic_field_model.dart';

class ConfigModel {
  // Fixed fields (always required)
  String? appName;
  String? packageName;
  String? baseUrl;
  String? cloneId;

  // Dynamic fields (varies between clones)
  List<DynamicFieldModel> fields = [];

  bool get isValid =>
      (appName?.isNotEmpty ?? false) && (packageName?.isNotEmpty ?? false);

  ConfigModel.fromJson(dynamic json) {
    appName = json['appName'];
    packageName = json['packageName'];
    baseUrl = json['baseUrl'];
    cloneId = json['cloneId'];

    // Parse dynamic fields
    if (json['fields'] != null && json['fields'] is Map) {
      final fieldsMap = json['fields'] as Map;
      fieldsMap.forEach((key, value) {
        fields.add(DynamicFieldModel.fromEntry(key.toString(), value));
      });
    }
  }
}
