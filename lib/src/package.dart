library crossdart.package;

import 'dart:io';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/util.dart';
import 'package:path/path.dart' as path;

abstract class Package {
  String get name;
  Version get version;
  Directory get symlink;
  Directory get root;
  Directory get lib;

  Iterable<FileSystemEntity> get children {
    return lib.listSync(recursive: true, followLinks: true);
  }

  Iterable<String> get filePaths {
    return files.map((f) => f.path.replaceAll(lib.path, ""));
  }

  Iterable<File> get files {
    return children.where((f) => f is File && f.path.endsWith(".dart"));
  }

  String toString() {
    return {"name": name, "version": version.toString()}.toString();
  }

  bool doesContainFile(String file) {
    return children.where((f) => f is File).map((f) => f.path).contains(file);
  }

  int get hashCode => hash([name, version]);

  bool operator ==(other) => other is Package
      && name == other.name
      && version == other.version;
}

class Sdk extends Package {
  String _name;
  String get name => _name;

  Version _version;
  Version get version => _version;
  Sdk(this._name, this._version);

  Directory get symlink => root;

  Directory get root => new Directory(config.sdkPath);

  Directory get lib => new Directory(path.join(root.path, "lib"));
}

class CustomPackage extends Package {
  String _name;
  String get name => _name;

  Version _version;
  Version get version => _version;

  CustomPackage(this._name, this._version);

  CustomPackage.fromName(this._name) {
    var dir = root.path;
    var name = path.basename(dir);
    var match = new RegExp(r"-([\d\.+]+)$").firstMatch(name);
    if (match != null) {
      _version = new Version.fromString(match[1]);
    }
  }

  Directory get symlink {
    return new Directory(path.join(config.installPath, "packages", name));
  }

  Directory get root {
    return lib.parent;
  }

  Directory get lib {
    return new Directory(new Directory(symlink.path).resolveSymbolicLinksSync());
  }
}

Iterable<CustomPackage> get customPackages {
  return new Directory(config.packagesPath).listSync(recursive: false).map((name) {
    return new CustomPackage.fromName(path.basename(name.path));
  });
}

Iterable<Package> get packages {
  return []..add(sdk)..addAll(customPackages);
}

Sdk _sdk;
Sdk get sdk {
  if (_sdk == null) {
    print(config.sdk.sdkVersion);
    _sdk = new Sdk("sdk", new Version.fromString(config.sdk.sdkVersion));
  }
  return _sdk;
}