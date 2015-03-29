library crossdart.config;

import 'package:path/path.dart';
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk_io.dart' show DirectoryBasedDartSdk;

class Config {
  final String sdkPath;
  final String installPath;
  final String htmlPath;
  final String templatesPath;

  const Config(this.sdkPath, this.installPath, this.htmlPath, this.templatesPath);

  Config.fromArgs(List args) :
    this.sdkPath = args[0],
    this.installPath = args[1],
    this.htmlPath = args[2],
    this.templatesPath = args[3];

  String get packagesPath => join(installPath, "packages");

  DartSdk get sdk {
    JavaSystemIO.setProperty("com.google.dart.sdk", sdkPath);
    return DirectoryBasedDartSdk.defaultSdk;
  }

}

Config config;