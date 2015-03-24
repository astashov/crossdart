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
    return file.replaceAll("${package.lib}/", "");
  }

  String get htmlPath {
    return "/" + p.join(package.name, _versionPart, "${path}.html");
  }

  String get writePath {
    var result = p.join(config.htmlPath, package.name, _versionPart);
    if (p.dirname(path) != ".") {
      result = p.join(result, p.dirname(path));
    }
    result = p.join(result, "${p.basename(path)}.html");
    return result;
  }

  String get _versionPart => package.version != null ? package.version.toPath() : "unknown";

  String toString() {
    var map = {"file": file, "package": package};
    return "<Location ${map.toString()}>";
  }
}