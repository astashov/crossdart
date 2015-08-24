library crossdart.pub_cache_package_loader;

import 'dart:async';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/version.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:crossdart/src/store/db_package_loader.dart';

var _logger = new Logger("store.load");

class PubCachePackageLoader {
  Config _config;

  PubCachePackageLoader(this._config);

  Future<Iterable<PackageInfo>> getAllPackageInfos() async {
    final Iterable<PackageInfo> packageInfosFromDb = await new DbPackageLoader(_config).getAllPackageInfos();
    final hostedPackageInfos = new Directory(_config.hostedPackagesRoot).listSync().map((packageDir) {
      final pubSpec = new File(p.join(packageDir.path, "pubspec.yaml"));
      if (_isLibExistsAndNotEmpty(packageDir) && pubSpec.existsSync()) {
        final yaml = loadYaml(pubSpec.readAsStringSync());
        final name = yaml["name"];
        final match = new RegExp("^" + name + r"-(.+)$").firstMatch(p.basename(packageDir.path));
        final version = new Version(match[1]);
        final id = _getIdForPackage(packageInfosFromDb, name, version);
        return new PackageInfo(name, version, source: PackageSource.HOSTED, id: id);
      } else {
        return null;
      }
    }).where((pi) => pi != null);

    final gitPackageInfos = new Directory(_config.gitPackagesRoot).listSync().map((packageDir) {
      final match = new RegExp(r"^(.+)-([a-z0-9]+)$").firstMatch(p.basename(packageDir.path));
      if (_isLibExistsAndNotEmpty(packageDir) && match != null) {
        final name = match[1];
        final version = new Version(match[2]);
        final id = _getIdForPackage(packageInfosFromDb, name, version);
        return new PackageInfo(name, version, source: PackageSource.GIT, id: id);
      } else {
        return null;
      }
    }).where((pi) => pi != null);

    final sdkPackageInfos = new Directory(_config.sdkPackagesRoot).listSync().map((packageDir) {
      final match = new RegExp(r"^sdk-(.+)$").firstMatch(p.basename(packageDir.path));
      final name = "sdk";
      final version = new Version(match[1]);
      final id = _getIdForPackage(packageInfosFromDb, name, version);
      return new PackageInfo(name, version, source: PackageSource.SDK, id: id);
    });

    return new List.from(hostedPackageInfos)..addAll(gitPackageInfos)..addAll(sdkPackageInfos);
  }

  int _getIdForPackage(Iterable<PackageInfo> packageInfosFromDb, String name, Version version) {
    final PackageInfo packageInfoFromDb = packageInfosFromDb.firstWhere((pi) {
      return pi.name == name && pi.version == version;
    }, orElse: () => null);
    return packageInfoFromDb != null ? packageInfoFromDb.id : null;
  }

  bool _isLibExistsAndNotEmpty(FileSystemEntity packageDir) {
    final directory = new Directory(p.join(packageDir.path, "lib"));
    return directory.existsSync() && directory.listSync(recursive: true).where((FileSystemEntity f) {
      var path = p.basename(f.path);
      return !path.startsWith("._") && path.endsWith(".dart");
    }).isNotEmpty;
  }

}
