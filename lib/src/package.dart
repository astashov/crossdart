library crossdart.package;

import 'dart:io';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/util.dart';
import 'package:path/path.dart' as path;

class PackageInfo {
  final String name;
  final Version version;
  const PackageInfo(this.name, this.version);

  String get htmlPath {
    return path.join(config.htmlPath, name, version.toPath());
  }

  Iterable<String> get generatedPaths {
    return new Directory(htmlPath)
        .listSync(recursive: true)
        .where((f) => f is File && f.path.endsWith(".html"))
        .map((s) => s.path.replaceAll(config.htmlPath, "").replaceAll(new RegExp(r".html$"), ""));
  }

  int get hashCode => hash([name, version]);

  bool operator ==(other) => other is PackageInfo
      && name == other.name
      && version == other.version;

  String toString() {
    return "<PackageInfo ${{"name": name, "version": version.toString()}}>";
  }
}

abstract class Package {
  PackageInfo get packageInfo;
  String get symlink;
  String get root;
  String get lib;

  String get name => packageInfo.name;
  Version get version => packageInfo.version;

  Iterable<FileSystemEntity> get children {
    return new Directory(lib).listSync(recursive: true, followLinks: true);
  }

  static Package fromFilePath(String filePath) {
    return packages.firstWhere((p) => p.doesContainFile(filePath));
  }

  Iterable<String> get filePaths {
    return files.map((f) => f.path.replaceAll(lib, ""));
  }

  Iterable<File> get files {
    return children.where((f) => f is File && f.path.endsWith(".dart"));
  }

  String toString() {
    return "<Package ${{"name": packageInfo.name, "version": packageInfo.version.toString()}}>";
  }

  bool doesContainFile(String file) {
    return children.where((f) => f is File).map((f) => f.path).contains(file);
  }

  int get hashCode => hash([packageInfo]);
  bool operator ==(other) => other is Package && packageInfo == other.packageInfo;
}

class Sdk extends Package {
  PackageInfo _packageInfo;
  PackageInfo get packageInfo => _packageInfo;

  Sdk(this._packageInfo);

  String get symlink => root;

  String get root => config.sdkPath;

  String get lib => path.join(root, "lib");
}

class CustomPackage extends Package {
  PackageInfo _packageInfo;
  PackageInfo get packageInfo => _packageInfo;

  CustomPackage(this._packageInfo);

  String get symlink {
    return path.join(config.installPath, "packages", packageInfo.name);
  }

  String get root {
    return path.dirname(lib);
  }

  String get lib {
    return new Directory(symlink).resolveSymbolicLinksSync();
  }
}

Iterable<CustomPackage> get customPackages {
  return new Directory(config.packagesPath).listSync(recursive: false).map((name) {
    var packageName =  path.basename(path.dirname(name.resolveSymbolicLinksSync()));
    var match = new RegExp(r"-([\d\.+]+)$").firstMatch(packageName);
    var version;
    if (match != null) {
      version = new Version.fromString(match[1]);
      packageName = packageName.replaceAll(new RegExp(r"-([\d\.+]+)$"), "");
    }
    return new CustomPackage(new PackageInfo(packageName, version));
  });
}

Iterable<Package> get packages {
  return []..add(sdk)..addAll(customPackages);
}

Sdk _sdk;
Sdk get sdk {
  if (_sdk == null) {
    _sdk = new Sdk(new PackageInfo("sdk", new Version.fromString(config.sdk.sdkVersion)));
  }
  return _sdk;
}