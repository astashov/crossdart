library crossdart.location;

import 'package:crossdart/src/util.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:path/path.dart' as p;

class Location {
  final String path;
  final Package package;

  Location(this.package, this.path);

  factory Location.fromEnvironment(Environment environment, String absolutePath) {
    var package = Package.fromAbsolutePath(environment, absolutePath);
    return new Location(package, package.relativePath(absolutePath));
  }

  int get hashCode => hash([path, package]);

  bool operator ==(other) => other is Location
      && path == other.path
      && package == other.package;

  String get file {
    return p.join(package.lib, path);
  }

  String get htmlPath {
    return "/" + p.join(package.name, _versionPart, "${path}.html");
  }

  String remotePath(int lineNumber) {
    if (package is Project) {
      var result = p.join("lib", path);
      if (lineNumber != null) {
        result += "#L${lineNumber + 1}";
      }
      return result;
    } else if (package is Sdk || package.source == PackageSource.HOSTED) {
      var result = p.join("http://crossdart.info", package.name, package.version.toPath(), "${path}.html");
      if (lineNumber != null) {
        result += "#line-${lineNumber}";
      }
      return result;
    } else if (package is CustomPackage && package.source == PackageSource.GIT) {
      return "TBD";
    } else {
      return null;
    }
  }

  String writePath(Config config) {
    var result = p.join(config.outputPath, package.name, _versionPart);
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