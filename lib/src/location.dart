library crossdart.location;

import 'package:crossdart/src/util.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/config.dart';
import 'package:path/path.dart' as p;

class Location {
  final String file;
  final Package package;

  const Location(this.file, this.package);

  int get hashCode => hash([file, package]);

  bool operator ==(other) => other is Location
      && file == other.file
      && package == other.package;

  String get path {
    return file.replaceAll("${package.lib.path}/", "");
  }

  String get htmlPath {
    return "/" + p.join(package.name, package.version.toPath(), "${path}.html");
  }

  String get writePath {
    return p.join(config.htmlPath, package.name, package.version.toPath(), p.dirname(path), "${p.basename(path)}.html");
  }

  String toString() {
    var map = {"file": file, "package": package};
    return "<Location ${map.toString()}>";
  }
}