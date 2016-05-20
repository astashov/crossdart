library crossdart.config;

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart' as yaml;
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/version.dart';
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk_io.dart' show DirectoryBasedDartSdk;
import 'package:googleapis_auth/auth.dart';

class Config {
  final String dirroot;
  final String sdkPath;
  final String installPath;
  final String outputPath;
  final String templatesPath;
  final String projectPath;
  final String pubCachePath;
  final String dbLogin;
  final String dbPassword;
  final String dbHost;
  final int dbPort;
  final String dbName;
  final String gcProjectName;
  final String gcZone;
  final String gcGroupName;
  final ServiceAccountCredentials credentials;
  final String bucket;
  final String gcsPrefix;

  final bool isDbUsed;
  final String part;

  static const String SDK_PATH = "sdkpath";
  static const String DIR_ROOT = "dirroot";
  static const String OUTPUT_PATH = "outputpath";
  static const String PROJECT_PATH = "projectpath";
  static const String PUB_CACHE_PATH = "pubcachepath";
  static const String PART = "part";

  Config._({
    this.dirroot,
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
    this.part,
    this.bucket,
    this.gcProjectName,
    this.gcZone,
    this.gcGroupName,
    this.credentials,
    this.gcsPrefix});

  factory Config.buildFromFiles({
      String dirroot,
      String part,
      String configFile,
      String pubCachePath,
      String sdkPath,
      String projectPath,
      bool isDbUsed,
      String outputPath}) {
    dirroot ??= Directory.current.path;
    configFile ??= path.join(dirroot, "config.yaml");
    var credentialsFile = path.join(dirroot, "credentials.yaml");
    var configValues = yaml.loadYaml(new File(path.join(dirroot, configFile)).readAsStringSync());
    var credentialsValues = yaml.loadYaml(
        new File(path.join(dirroot, credentialsFile)).readAsStringSync());
    var cloudflareValues = credentialsValues["cloudflare"];
    var serviceAccountCredentials = new ServiceAccountCredentials.fromJson(
        JSON.encode(credentialsValues["google_cloud"]));
    return new Config._(
        dirroot: dirroot,
        sdkPath: configValues["sdk"],
        installPath: configValues["install_path"],
        outputPath: outputPath ?? configValues["output_path"],
        templatesPath: configValues["templates_path"],
        projectPath: projectPath,
        pubCachePath: configValues["pub_cache_path"],
        isDbUsed: isDbUsed,
        dbLogin: configValues["db_login"],
        dbPassword: configValues["db_password"],
        dbHost: configValues["db_host"],
        dbPort: configValues["db_port"],
        dbName: configValues["db_name"],
        part: part,
        bucket: configValues["bucket"],
        gcsPrefix: configValues["gcs_prefix"],
        gcProjectName: configValues["gc_project_name"],
        gcZone: configValues["gc_zone"],
        gcGroupName: configValues["gc_group_name"],
        credentials: serviceAccountCredentials);
  }

  int get currentPart => int.parse(part.split("/")[0]);
  int get totalParts => int.parse(part.split("/")[1]);

  String get packagesPath {
    if (projectPath != null) {
      return path.join(projectPath, ".packages");
    } else if (installPath != null) {
      return path.join(installPath, ".packages");
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
    return new Directory(path.join(outputPath, gcsPrefix)).listSync().where((f) => f is Directory).map((Directory dir) {
      var versions = dir.listSync().where((f) => f is Directory).map((d) => path.basename(d.path)).toList();
      versions.sort();
      return versions.map((version) => new PackageInfo(path.basename(dir.path), new Version(version)));
    });
  }

  DateTime currentDate;

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
      String dbName,
      String part}) {
    return new Config._(
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
        dbName: dbName != null ? dbName : this.dbName,
        part: part ?? this.part);
  }
}
