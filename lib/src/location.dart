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

  String writePath(Config config) {
    var result = p.join(config.htmlPath, package.name, _versionPart);
    if (p.dirname(path) != ".") {
      result = p.join(result, p.dirname(path));
    }
    result = p.join(result, "${p.basename(path)}.html");
    return result;
  }

  String get _versionPart => package.version != null ? package.version.toPath() : "unknown";

  String toString() {
    var map = {"path": path, "package": package};
    return "<Location ${map.toString()}>";
  }
}