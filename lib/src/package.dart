library crossdart.package;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/util.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:logging/logging.dart';
import 'package:pub_semver/pub_semver.dart';

Logger _logger = new Logger("package");

//TODO: Add package type

abstract class Package implements Comparable<Package> {
  final PackageInfo packageInfo;
  final Config config;
  final Iterable<String> paths;

  Package(this.config, this.packageInfo, this.paths);

  static Package fromAbsolutePath(Environment environment, String filePath) {
    return environment.packagesByFiles[filePath];
  }

  Package update({Config config, PackageInfo packageInfo, Iterable<String> paths});

  String get name => packageInfo.name;
  Version get version => packageInfo.version;
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

  String get docsUrl {
    return "https://www.dartdocs.org/documentation/${name}/${version}";
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
        "source": source,
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
      Iterable<String> paths) :
      super(config, packageInfo, paths);

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
      return p.join(config.dartSdk, "lib");
    } else {
      return p.join(config.sdkPackagesRoot, packageInfo.dirname, "lib");
    }
  }

  Sdk update({Config config, PackageInfo packageInfo, String description, Iterable<String> paths}) {
    return new Sdk(
        config != null ? config : this.config,
        packageInfo != null ? packageInfo : this.packageInfo,
        paths != null ? paths : this.paths);
  }
}

class Project extends Package {
  Project(
      Config config,
      PackageInfo packageInfo,
      Iterable<String> paths) :
      super(config, packageInfo, paths);

  Iterable<Package> dependencies(Environment environment) {
    return environment.customPackages.where((cp) => ["barback", "stack_trace"].contains(cp.packageInfo.name));
  }

  String get _root => config.input;
  String get lib => p.join(_root, "lib");

  Project update({Config config, PackageInfo packageInfo, String description, Iterable<String> paths}) {
    return new Project(
        config != null ? config : this.config,
        packageInfo != null ? packageInfo : this.packageInfo,
        paths != null ? paths : this.paths);
  }
}


class CustomPackage extends Package {
  CustomPackage(
      Config config,
      PackageInfo packageInfo,
      Iterable<String> paths) :
      super(config, packageInfo, paths);

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

  CustomPackage update({Config config, PackageInfo packageInfo, Iterable<String> paths}) {
    return new CustomPackage(
        config != null ? config : this.config,
        packageInfo != null ? packageInfo : this.packageInfo,
        paths != null ? paths : this.paths);
  }
}

Future<Package> buildFromFileSystem(Config config, PackageInfo packageInfo) {
  if (packageInfo.isSdk) {
    return buildSdkFromFileSystem(config, packageInfo);
  } else {
    return buildCustomPackageFromFileSystem(config, packageInfo);
  }
}

Future<Sdk> buildSdkFromFileSystem(Config config, PackageInfo packageInfo) async {
  String lib = p.join(packageInfo.getDirectoryInPubCache(config), "lib");
  var source = PackageSource.SDK;

  var paths = new Directory(lib).listSync(recursive: true).where(_isDartFile).map((file) {
    return file.path.replaceAll(lib, "").replaceFirst(new RegExp(r"^/"), "");
  });

  return new Sdk(config, packageInfo.update(source: source), paths);
}

Project buildProjectFromFileSystem(Config config) {
  var lib = p.join(config.input, "lib");

  var paths = new Directory(lib).listSync(recursive: true).where(_isDartFile).map((file) {
    return file.path.replaceAll(lib, "").replaceFirst(new RegExp(r"^/"), "");
  });

  var pubspec = loadYaml(new File(p.join(config.input, "pubspec.yaml")).readAsStringSync());

  return new Project(config, new PackageInfo(pubspec["name"], new Version.parse(pubspec["version"])), paths);
}

bool _isDartFile(FileSystemEntity f) {
  return f is File && !p.basename(f.path).startsWith("._") && f.path.endsWith(".dart");
}

Future<CustomPackage> buildCustomPackageFromFileSystem(Config config, PackageInfo packageInfo) async {
  var root = packageInfo.getDirectoryInPubCache(config);
  var lib = p.join(root, "lib");

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

  return new CustomPackage(config, packageInfo.update(source: source), paths);
}
