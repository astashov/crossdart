library crossdart.config;

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/version.dart';
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk_io.dart' show DirectoryBasedDartSdk;
import 'package:sqljocky/sqljocky.dart';


class Config {
  final String sdkPath;
  final String installPath;
  final String outputPath;
  final String templatesPath;
  final String projectPath;
  final String packagesPath;
  final bool isDbUsed;
  final String dbLogin;
  final String dbPassword;
  final String dbHost;
  final String dbPort;
  final String dbName;

  static const String SDK_PATH = "sdkpath";
  static const String INSTALL_PATH = "installpath";
  static const String OUTPUT_PATH = "outputpath";
  static const String TEMPLATES_PATH = "templatespath";
  static const String PROJECT_PATH = "projectpath";
  static const String PACKAGES_PATH = "packagespath";
  static const String DB_LOGIN = "dblogin";
  static const String DB_PASSWORD = "dbpassword";
  static const String DB_HOST = "dbhost";
  static const String DB_PORT = "dbport";
  static const String DB_NAME = "dbname";

  Config({
    this.sdkPath,
    this.installPath,
    this.outputPath,
    this.templatesPath,
    this.projectPath,
    this.packagesPath,
    this.isDbUsed,
    this.dbLogin,
    this.dbPassword,
    this.dbHost,
    this.dbPort,
    this.dbName});

  String __packagesRoot;
  String get _packagesRoot {
    if (__packagesRoot == null) {
      var lib = (new Directory(packagesPath).listSync().first).resolveSymbolicLinksSync();
      __packagesRoot = path.dirname(path.dirname(lib));
      if (!__packagesRoot.endsWith("/")) {
        __packagesRoot += "/";
      }
    }
    return __packagesRoot;
  }

  String get hostedPackagesRoot {
    return _packagesRoot.replaceFirst("/git/", "/hosted/pub.dartlang.org/").replaceFirst(new RegExp(r"/$"), "");
  }

  String get gitPackagesRoot {
    return _packagesRoot.replaceFirst("/hosted/pub.dartlang.org/", "/git/").replaceFirst(new RegExp(r"/$"), "");
  }

  DartSdk get sdk {
    JavaSystemIO.setProperty("com.google.dart.sdk", sdkPath);
    return DirectoryBasedDartSdk.defaultSdk;
  }

  Iterable<Iterable<PackageInfo>> get generatedPackageInfos {
    return new Directory(outputPath).listSync().where((f) => f is Directory).map((Directory dir) {
      var versions = dir.listSync().where((f) => f is Directory).map((d) => path.basename(d.path)).toList();
      versions.sort();
      return versions.map((version) => new PackageInfo(path.basename(dir.path), new Version(version)));
    });
  }

  ConnectionPool _dbPool;
  ConnectionPool get dbPool {
    if (_dbPool == null) {
      if (this.isDbUsed) {
        var login = dbLogin != null ? dbLogin : "root";
        var password = dbPassword != null ? dbPassword : "";
        var host = dbHost != null ? dbHost : "localhost";
        var port = dbPort != null ? dbPort : "3306";
        var name = dbName != null ? dbName : "crossdart";
        _dbPool = new ConnectionPool(
            host: host,
            port: int.parse(port),
            user: login,
            password: (password == '' ? null : password),
            db: name,
            max: 5);
      } else {
        throw "This application should not use the database";
      }
    }
    return _dbPool;
  }

  void deallocDbPool() {
    if (_dbPool != null) {
      _dbPool.close();
    }
    _dbPool = null;
  }
}
