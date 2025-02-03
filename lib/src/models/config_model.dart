import 'package:generate_clone/src/models/color_model.dart';
import 'package:generate_clone/src/models/gradient_color_model.dart';

class ConfigModel {
  String? appName;
  String? packageName;
  List<ColorModel>? colors;
  List<GradientColorModel>? gradientsColors;
  String? baseUrl;
  String? cloneId;

  bool get isValid =>
      (appName?.isNotEmpty ?? false) && (packageName?.isNotEmpty ?? false);

  ConfigModel.fromJson(dynamic json) {
    appName = json['appName'];
    packageName = json['packageName'];
    baseUrl = json['baseUrl'];
    cloneId = json['cloneId'];
    if (json['colors'] != null) {
      colors = [];
      json['colors'].forEach((v) {
        colors?.add(ColorModel.fromJson(v));
      });
    }
    if (json['linearGradients'] != null) {
      gradientsColors = [];
      json['linearGradients'].forEach((v) {
        gradientsColors?.add(GradientColorModel.fromJson(v));
      });
    }
  }
}
