library crossdart.entity;

import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/cache.dart';
import 'package:crossdart/src/util.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/environment.dart';

abstract class Entity {
  Location location;
  String name;
  int offset;
  int end;

  int _lineNumber;
  int get lineNumber {
    if (offset != null) {
      if (_lineNumber == null) {
        _lineNumber = cache.lineNumber(location.file, offset);
      }
      return _lineNumber;
    } else {
      return null;
    }
  }

  Location _buildLocation(Environment environment, String file, [Package package]) {
    if (package == null) {
      package = environment.packagesByFiles[file];
    }
    return new Location(environment.config, file, package);
  }

  Entity(Environment environment, String file, {this.name, this.offset, this.end, Package package}) {
    this.location = _buildLocation(environment, file, package);
  }

  int get hashCode => hash([location, name, offset, end]);

  bool operator ==(other) => other is Entity
      && location == other.location
      && name == other.name
      && offset == other.offset
      && end == other.end;

  String toString() {
    var map = {"location": location, "name": name, "offset": offset, "end": end};
    return "<${runtimeType} ${map.toString()}>";
  }
}

class Declaration extends Entity {
  Declaration(Environment environment, String file, {String name, int offset, int end, Package package}) : super(environment, file, name: name, offset: offset, end: end, package: package);
}
class Import extends Declaration {
  Import(Environment environment, String file, {String name, Package package}) : super(environment, file, name: name, package: package);
}
class Token extends Entity {
  Token(Environment environment, String file, {String name, int offset, int end, Package package}) : super(environment, file, name: name, offset: offset, end: end, package: package);
}
class Reference extends Token {
  Reference(Environment environment, String file, {String name, int offset, int end, Package package}) : super(environment, file, name: name, offset: offset, end: end, package: package);
}