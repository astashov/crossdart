library crossdart.package;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:crossdart/src/util/map.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/util.dart';
import 'package:crossdart/src/store.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

//enum PackageType { IO, HTML }
enum PackageSource { GIT, HOSTED }
Map<PackageSource, int> packageSourceIds = {PackageSource.GIT: 1, PackageSource.HOSTED: 2};

abstract class Package {
  final int id;
  final PackageInfo packageInfo;
  //final PackageType type;
  final PackageSource source;
  final String description;
  final Config config;
  final Iterable<String> paths;

  Package(this.config, this.id, this.packageInfo, this.source, this.description, this.paths);

  static Package fromAbsolutePath(Environment environment, String filePath) {
    return environment.packages.firstWhere((p) => p.absolutePaths.contains(filePath));
  }

  String get name => packageInfo.name;
  Version get version => packageInfo.version;

  String get lib;
  Iterable<Package> dependencies(Environment environment);

  Iterable<String> get absolutePaths {
    return paths.map(absolutePath);
  }

  String absolutePath(String relativePath) {
    return p.join(lib, relativePath);
  }

  String relativePath(String absolutePath) {
    return absolutePath.replaceFirst(lib, "").replaceFirst(new RegExp(r"^/"), "");
  }

  String toString() {
    return "<Package ${toMap()}>";
  }

  Map<String, Object> toMap() {
    return {
        "name": name,
        "version": version,
        "id": id,
        "source": source,
        "description": description,
        "paths": paths};
  }

  int get hashCode => hash([packageInfo]);
  bool operator ==(other) => other is Package && packageInfo == other.packageInfo;
}


class Sdk extends Package {
  Sdk(
      Config config,
      int id,
      PackageInfo packageInfo,
      PackageSource source,
      String description,
      Iterable<String> paths) :
      super(config, id, packageInfo, source, description, paths);

  Iterable<Package> dependencies(_) => [];

  String get _root => config.sdkPath;
  String get lib => p.join(_root, "lib");
}

class Project extends Package {
  Project(
      Config config,
      int id,
      PackageInfo packageInfo,
      PackageSource source,
      String description,
      Iterable<String> paths) :
      super(config, id, packageInfo, source, description, paths);

  Iterable<Package> dependencies(_) => [];

  String get _root => config.projectPath;
  String get lib => p.join(_root, "lib");
}


class CustomPackage extends Package {
  CustomPackage(
      Config config,
      int id,
      PackageInfo packageInfo,
      PackageSource source,
      String description,
      Iterable<String> paths) :
      super(config, id, packageInfo, source, description, paths);

  String get _packagesRoot {
    if (source == PackageSource.GIT) {
      return config.gitPackagesRoot;
    } else {
      return config.hostedPackagesRoot;
    }
  }

  String get _root => p.join(_packagesRoot, "${name}-${version}");

  String get lib => p.join(_root, "lib");

  Iterable<Package> _dependencies;
  Iterable<Package> dependencies(Environment environment) {
    if (_dependencies == null) {
      var pubspecPath = p.join(_root, "pubspec.yaml");
      var file = new File(pubspecPath);
      if (file.existsSync()) {
        var yaml = loadYaml(file.readAsStringSync());
        var dependencies = yaml["dependencies"];
        var packages = [];
        if (dependencies != null) {
          dependencies.forEach((name, version) {
            var package = environment.customPackages.firstWhere((cp) => cp.packageInfo.name == name);
            if (package != null) {
              packages.add(package);
            }
          });
        }
        _dependencies = packages;
      } else {
        _dependencies = [];
      }
    }
    return _dependencies;
  }
}


Future<Package> buildFromDatabase(Config config, PackageInfo packageInfo) async {
  var result = await (await dbPool.query("""
      SELECT id, source_type, description FROM packages WHERE name = '${packageInfo.name}' AND version = '${packageInfo.version}'  
  """)).toList();
  var row = result.isNotEmpty ? result.first : null;
  if (row != null) {
    var paths = (await (await dbPool.query("""
        SELECT DISTINCT path FROM entities WHERE package_id = ${row.id} AND type = ${entityTypeIds[Reference]}  
    """)).toList()).map((r) => r.path);
    var source = key(packageSourceIds, row.source_type);
    if (packageInfo.name == "sdk") {
      return new Sdk(config, row.id, packageInfo, source, null, paths);
    } else {
      return new CustomPackage(config, row.id, packageInfo, source, null, paths);
    }
  } else {
    return null;
  }
}

Future<Sdk> buildSdkFromFileSystem(Config config, PackageInfo packageInfo) async {
  var lib = p.join(config.sdkPath, "lib");
  var source = PackageSource.HOSTED;

  var id = null;
  if (config.isDbUsed) {
    id = await getPackageId(packageInfo);
    if (id == null) {
      id = await storePackage(packageInfo, source, null);
    }
  }
  var paths = new Directory(lib).listSync(recursive: true).where((f) => f is File && f.path.endsWith(".dart")).map((file) {
    return file.path.replaceAll(lib, "").replaceFirst(new RegExp(r"^/"), "");
  });

  return new Sdk(config, id, packageInfo, source, null, paths);
}

Project buildProjectFromFileSystem(Config config) {
  var lib = p.join(config.projectPath, "lib");

  var paths = new Directory(lib).listSync(recursive: true).where((f) => f is File && f.path.endsWith(".dart")).map((file) {
    return file.path.replaceAll(lib, "").replaceFirst(new RegExp(r"^/"), "");
  });

  return new Project(config, null, new PackageInfo("project", new Version("")), null, null, paths);
}


Future<CustomPackage> buildCustomPackageFromFileSystem(Config config, PackageInfo packageInfo) async {
  Directory getDirectory() {
    return new Directory(config.packagesPath).listSync().firstWhere((entity) {
      return p.basename(entity.path) == packageInfo.name;
    }, orElse: () => null);
  }

  var lib = getDirectory().resolveSymbolicLinksSync();
  var root = p.dirname(lib);

  YamlNode getPubspec() {
    var pubspecPath = p.join(root, "pubspec.yaml");
    var file = new File(pubspecPath);
    if (file.existsSync()) {
      return loadYaml(file.readAsStringSync());
    } else {
      return null;
    }
  }

  var source;
  if (lib.contains("/git/")) {
    source = PackageSource.GIT;
  } else {
    source = PackageSource.HOSTED;
  }
  var paths = new Directory(lib).listSync(recursive: true).where((f) => f is File && f.path.endsWith(".dart")).map((file) {
    return file.path.replaceAll(lib, "").replaceFirst(new RegExp(r"^/"), "");
  });

  var pubspec = getPubspec();
  var id = null;
  if (config.isDbUsed) {
    var id = await getPackageId(packageInfo);
    if (id == null) {
      id = await storePackage(packageInfo, source, pubspec["description"]);
    }
  }

  return new CustomPackage(config, id, packageInfo, source, pubspec["description"], paths);
}