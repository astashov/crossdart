library crossdart.config;

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/html/url.dart';
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk_io.dart' show DirectoryBasedDartSdk;

class Config {
  final String sdkPath;
  final String installPath;
  final String outputPath;
  final String templatesPath;
  final String projectPath;
  final String pubCachePath;
  final bool isDbUsed;
  final String dbLogin;
  final String dbPassword;
  final String dbHost;
  final String dbPort;
  final String dbName;
  final String part;

  static const String SDK_PATH = "sdkpath";
  static const String INSTALL_PATH = "installpath";
  static const String OUTPUT_PATH = "outputpath";
  static const String TEMPLATES_PATH = "templatespath";
  static const String PROJECT_PATH = "projectpath";
  static const String PUB_CACHE_PATH = "pubcachepath";
  static const String DB_LOGIN = "dblogin";
  static const String DB_PASSWORD = "dbpassword";
  static const String DB_HOST = "dbhost";
  static const String DB_PORT = "dbport";
  static const String DB_NAME = "dbname";
  static const String PART = "part";

  Config({
    this.sdkPath,
    this.installPath,
    this.outputPath,
    this.templatesPath,
    this.projectPath,
    this.pubCachePath,
    this.isDbUsed,
    this.dbLogin,
    this.dbPassword,
    this.dbHost,
    this.dbPort,
    this.dbName,
    this.part});

  int get currentPart => int.parse(part.split("/")[0]);
  int get totalParts => int.parse(part.split("/")[1]);

  String get packagesPath {
    if (projectPath != null) {
      return path.join(projectPath, "packages");
    } else if (installPath != null) {
      return path.join(installPath, "packages");
    } else {
      throw "Cannot generate packagesPath, neither projectPath nor installPath are provided";
    }
  }

  String get hostedPackagesRoot {
    return path.join(pubCachePath, "hosted", "pub.dartlang.org");
  }

  String get gitPackagesRoot {
    return path.join(pubCachePath, "git");
  }

  String get sdkPackagesRoot {
    return path.join(pubCachePath, "sdk");
  }

  DartSdk get sdk {
    JavaSystemIO.setProperty("com.google.dart.sdk", sdkPath);
    return DirectoryBasedDartSdk.defaultSdk;
  }

  Iterable<Iterable<PackageInfo>> get generatedPackageInfos {
    return new Directory(path.join(outputPath, PATH_PREFIX)).listSync().where((f) => f is Directory).map((Directory dir) {
      var versions = dir.listSync().where((f) => f is Directory).map((d) => path.basename(d.path)).toList();
      versions.sort();
      return versions.map((version) => new PackageInfo(path.basename(dir.path), new Version(version)));
    });
  }

  DateTime _currentDate;
  DateTime get currentDate {
    if (_currentDate == null) {
      _currentDate = new DateTime.now().toUtc();
    }
    return _currentDate;
  }

  String _currentDir;
  String get currentDir {
    if (_currentDir == null) {
      _currentDir = new File(".").resolveSymbolicLinksSync();
    }
    return _currentDir;
  }

  Config copy({
      String sdkPath,
      String installPath,
      String outputPath,
      String templatesPath,
      String projectPath,
      String pubCachePath,
      bool isDbUsed,
      String dbLogin,
      String dbPassword,
      String dbHost,
      String dbPort,
      String dbName}) {
    return new Config(
        sdkPath: sdkPath != null ? sdkPath : this.sdkPath,
        installPath: installPath != null ? installPath : this.installPath,
        outputPath: outputPath != null ? outputPath : this.outputPath,
        templatesPath: templatesPath != null ? templatesPath : this.templatesPath,
        projectPath: projectPath != null ? projectPath : this.projectPath,
        pubCachePath: pubCachePath != null ? pubCachePath : this.pubCachePath,
        isDbUsed: isDbUsed != null ? isDbUsed : this.isDbUsed,
        dbLogin: dbLogin != null ? dbLogin : this.dbLogin,
        dbPassword: dbPassword != null ? dbPassword : this.dbPassword,
        dbHost: dbHost != null ? dbHost : this.dbHost,
        dbPort: dbPort != null ? dbPort : this.dbPort,
        dbName: dbName != null ? dbName : this.dbName);
  }
}
