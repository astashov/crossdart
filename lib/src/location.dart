library crossdart.location;

import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:crossdart/src/util.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:path/path.dart' as p;

class Location {
  final String path;
  final Package package;
  final Config config;

  Location(this.config, this.package, this.path);

  factory Location.fromEnvironment(Environment environment, String absolutePath) {
    var package = Package.fromAbsolutePath(environment, absolutePath);
    return new Location(environment.config, package, package.relativePath(absolutePath));
  }

  int get hashCode => hash([path, package]);

  bool operator ==(other) => other is Location
      && path == other.path
      && package == other.package;

  String get file {
    return p.join(package.lib, path);
  }

  String get htmlPath {
    return "/" + p.join("p", package.name, _versionPart, "${path}.html");
  }

  String remotePath(int lineNumber, [String pubspecLockPath]) {
    if (package is Project) {
      var result = p.join("lib", path);
      if (lineNumber != null) {
        result += "#L${lineNumber + 1}";
      }
      return result;
    } else if (package is Sdk || package.source == PackageSource.HOSTED) {
      var result = p.join("http://crossdart.info", config.gcsPrefix, package.name, package.version.toPath(), "${path}.html");
      if (lineNumber != null) {
        result += "#line-${lineNumber}";
      }
      return result;
    } else if (package is CustomPackage && package.source == PackageSource.GIT && pubspecLockPath != null) {
      var pubspecLockFile = new File(pubspecLockPath);
      if (pubspecLockFile.existsSync()) {
        var yaml = loadYaml(pubspecLockFile.readAsStringSync());
        String ref = yaml["packages"][package.name]["description"]["resolved-ref"];
        String url = yaml["packages"][package.name]["description"]["url"];
        url = url.replaceAll("git@github.com:", "https://github.com/");
        url = url.replaceAll(new RegExp(r".git$"), "");
        var result = p.join(url, "tree", ref, "lib", path);
        if (lineNumber != null) {
          result += "#L${lineNumber + 1}";
        }
        return result;
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  String get writePath {
    var result = p.join(config.outputPath, config.gcsPrefix, package.name, _versionPart);
    if (p.dirname(path) != ".") {
      result = p.join(result, p.dirname(path));
    }
    result = p.join(result, "${p.basename(path)}.html");
    return result;
  }

  String get _versionPart => package.version != null ? package.version.toPath() : "unknown";

  String toString() {
    return "<Location ${toMap()}>";
  }

  Map toMap() {
    return {"path": path, "package": package};
  }
}