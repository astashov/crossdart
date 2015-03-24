library crossdart.entity;

import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/cache.dart';
import 'package:crossdart/src/util.dart';
import 'package:crossdart/src/package.dart';

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

  Location _buildLocation(String file) {
    var package = packages.firstWhere((package) => package.doesContainFile(file));
    return new Location(file, package);
  }

  Entity(String file, {this.name, this.offset, this.end}) {
    this.location = _buildLocation(file);
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
  Declaration(String file, {String name, int offset, int end}) : super(file, name: name, offset: offset, end: end);
}
class Reference extends Entity {
  Reference(String file, {String name, int offset, int end}) : super(file, name: name, offset: offset, end: end);
}
class Import extends Declaration {
  Import(String file, {String name}) : super(file, name: name);
}