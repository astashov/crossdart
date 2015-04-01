library crossdart.config;

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/version.dart';
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

  factory Config.build(List args) {
    return new Config.fromArgs(args);
  }

  String get packagesPath => path.join(installPath, "packages");

  DartSdk get sdk {
    JavaSystemIO.setProperty("com.google.dart.sdk", sdkPath);
    return DirectoryBasedDartSdk.defaultSdk;
  }

  Iterable<Iterable<PackageInfo>> get generatedPackageInfos {
    return new Directory(htmlPath).listSync().where((f) => f is Directory).map((Directory dir) {
      var versions = dir.listSync().where((f) => f is Directory).map((d) => path.basename(d.path)).toList();
      versions.sort();
      return versions.map((version) => new PackageInfo(this, path.basename(dir.path), new Version(version)));
    });
  }

}