library crossdart.package;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/util.dart';
import 'package:crossdart/src/store.dart';
import 'package:sqljocky/sqljocky.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:crossdart/src/installer/installer.dart';
import 'package:logging/logging.dart';
import 'package:pub_semver/pub_semver.dart';

Logger _logger = new Logger("package");

//TODO: Add package type
//enum PackageType { IO, HTML }

abstract class Package implements Comparable<Package> {
  final PackageInfo packageInfo;
  //final PackageType type;
  final String description;
  final Config config;
  final Iterable<String> paths;

  Package(this.config, this.packageInfo, this.description, this.paths);

  static Package fromAbsolutePath(Environment environment, String filePath) {
    return environment.packagesByFiles[filePath];
  }

  Package update({Config config, PackageInfo packageInfo, String description, Iterable<String> paths});
  Future<Package> updateId([QueriableConnection conn]);

  String get name => packageInfo.name;
  Version get version => packageInfo.version;
  int get id => packageInfo.id;
  DateTime get createdAt => packageInfo.createdAt;
  PackageSource get source => packageInfo.source;
  String get dirname => packageInfo.dirname;

  String get lib;
  Iterable<Package> dependencies(Environment environment);

  Iterable<String> get absolutePaths {
    return paths.map(absolutePath);
  }

  String absolutePath(String relativePath) {
    return p.join(lib, relativePath);
  }

  String get pubUrl {
    return "https://pub.dartlang.org/packages/${name}";
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

  int compareTo(Package other) {
    return packageInfo.compareTo(other.packageInfo);
  }
}


class Sdk extends Package {
  Sdk(
      Config config,
      PackageInfo packageInfo,
      String description,
      Iterable<String> paths) :
      super(config, packageInfo, description, paths);

  Iterable<Package> _dependencies;
  Iterable<Package> dependencies(Environment environment) {
    if (_dependencies == null) {
      var names = ["barback", "stack_trace"];
      _dependencies = environment.customPackages.where((cp) => names.contains(cp.packageInfo.name));
    }
    return _dependencies;
  }

  String get lib {
    if (packageInfo.version.toString() == config.sdk.sdkVersion) {
      return p.join(config.sdkPath, "lib");
    } else {
      return p.join(config.sdkPackagesRoot, packageInfo.dirname, "lib");
    }
  }

  Sdk update({Config config, PackageInfo packageInfo, String description, Iterable<String> paths}) {
    return new Sdk(
        config != null ? config : this.config,
        packageInfo != null ? packageInfo : this.packageInfo,
        description != null ? description : this.description,
        paths != null ? paths : this.paths);
  }
  Future<Sdk> updateId([QueriableConnection conn]) async {
    return update(packageInfo: packageInfo.update(id: await getPackageId(config, packageInfo, conn)));
  }
}

class Project extends Package {
  Project(
      Config config,
      PackageInfo packageInfo,
      String description,
      Iterable<String> paths) :
      super(config, packageInfo, description, paths);

  Iterable<Package> dependencies(Environment environment) {
    return environment.customPackages.where((cp) => ["barback", "stack_trace"].contains(cp.packageInfo.name));
  }

  String get _root => config.projectPath;
  String get lib => p.join(_root, "lib");

  Project update({Config config, PackageInfo packageInfo, String description, Iterable<String> paths}) {
    return new Project(
        config != null ? config : this.config,
        packageInfo != null ? packageInfo : this.packageInfo,
        description != null ? description : this.description,
        paths != null ? paths : this.paths);
  }
  Future<Project> updateId([QueriableConnection conn]) async {
    return update(packageInfo: packageInfo.update(id: await getPackageId(config, packageInfo, conn)));
  }
}


class CustomPackage extends Package {
  CustomPackage(
      Config config,
      PackageInfo packageInfo,
      String description,
      Iterable<String> paths) :
      super(config, packageInfo, description, paths);

  String get _packagesRoot {
    if (source == PackageSource.GIT) {
      return config.gitPackagesRoot;
    } else {
      return config.hostedPackagesRoot;
    }
  }

  String get _root => p.join(_packagesRoot, "${name}-${version}");

  String get lib => p.join(_root, "lib");

  List<Package> _dependencies;
  Iterable<Package> dependencies(Environment environment) {
    if (_dependencies == null) {
      _dependencies = [environment.sdk];
      var pubspecPath = p.join(_root, "pubspec.yaml");
      var file = new File(pubspecPath);
      if (file.existsSync()) {
        var yaml = loadYaml(file.readAsStringSync());
        var dependencies = yaml["dependencies"];
        if (dependencies != null) {
          dependencies.forEach((name, version) {
            var package = environment.customPackages.firstWhere((cp) => cp.packageInfo.name == name, orElse: () => null);
            if (package != null) {
              _dependencies.add(package);
            }
          });
        }
      }
    }
    return _dependencies;
  }

  CustomPackage update({Config config, PackageInfo packageInfo, String description, Iterable<String> paths}) {
    return new CustomPackage(
        config != null ? config : this.config,
        packageInfo != null ? packageInfo : this.packageInfo,
        description != null ? description : this.description,
        paths != null ? paths : this.paths);
  }
  Future<CustomPackage> updateId([QueriableConnection conn]) async {
    return update(packageInfo: packageInfo.update(id: await getPackageId(config, packageInfo, conn)));
  }
}

Future<Package> buildFromFileSystem(Config config, PackageInfo packageInfo) {
  if (packageInfo.isSdk) {
    return buildSdkFromFileSystem(config, packageInfo);
  } else {
    return buildCustomPackageFromFileSystem(config, packageInfo);
  }
}

Future<Package> buildFromDatabase(Config config, PackageInfo packageInfo) async {
  var result = await (await dbPool(config).query("""
      SELECT id, source_type, description FROM packages WHERE name = '${packageInfo.name}' AND version = '${packageInfo.version}'  
  """)).toList();
  var row = result.isNotEmpty ? result.first : null;
  if (row != null) {
    var paths = (await (await dbPool(config).query("""
        SELECT DISTINCT path FROM entities WHERE package_id = ${row.id} AND type = 'Reference'
    """)).toList()).map((r) => r.path);
    var source = packageSourceMapping[row.source_type];
    if (packageInfo.isSdk) {
      return new Sdk(config, packageInfo.update(id: row.id, source: packageSourceMapping[row.source_type]), null, paths);
    } else {
      return new CustomPackage(config, packageInfo.update(id: row.id, source: source), null, paths);
    }
  } else {
    return null;
  }
}

Future<Sdk> buildSdkFromFileSystem(Config config, PackageInfo packageInfo) async {
  String lib = p.join(packageInfo.getDirectoryInPubCache(config), "lib");
  var source = PackageSource.SDK;

  var id = packageInfo.id;
  if (config.isDbUsed && id == null) {
    id = await getPackageId(config, packageInfo);
  }
  var paths = new Directory(lib).listSync(recursive: true).where(_isDartFile).map((file) {
    return file.path.replaceAll(lib, "").replaceFirst(new RegExp(r"^/"), "");
  });

  return new Sdk(config, packageInfo.update(id: id, source: source), null, paths);
}

Project buildProjectFromFileSystem(Config config) {
  var lib = p.join(config.projectPath, "lib");

  var paths = new Directory(lib).listSync(recursive: true).where(_isDartFile).map((file) {
    return file.path.replaceAll(lib, "").replaceFirst(new RegExp(r"^/"), "");
  });

  return new Project(config, new PackageInfo("project", new Version.parse("0.0.1")), null, paths);
}

bool _isDartFile(FileSystemEntity f) {
  return f is File && !p.basename(f.path).startsWith("._") && f.path.endsWith(".dart");
}

Future<CustomPackage> buildCustomPackageFromFileSystem(Config config, PackageInfo packageInfo) async {
  var root = packageInfo.getDirectoryInPubCache(config);
  if (root == null) {
    new Installer(config, packageInfo).install();
    root = packageInfo.getDirectoryInPubCache(config);
  }
  var lib = p.join(root, "lib");

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
  final libDirectory = new Directory(lib);
  Iterable<String> paths;
  if (libDirectory.existsSync()) {
    paths = new Directory(lib).listSync(recursive: true).where(_isDartFile).map((file) {
      return file.path.replaceAll(lib, "").replaceFirst(new RegExp(r"^/"), "");
    });
  } else {
    paths = [];
  }

  var pubspec = getPubspec();
  int id = packageInfo.id;
  if (config.isDbUsed && id == null) {
    id = await getPackageId(config, packageInfo);
  }

  return new CustomPackage(config, packageInfo.update(id: id, source: source), pubspec["description"], paths);
}
