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

  Entity(this.location, {this.name, this.offset, this.end});

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
  Declaration(Location location, {String name, int offset, int end}) : super(location, name: name, offset: offset, end: end);
}
class Import extends Declaration {
  Import(Location location, {String name}) : super(location, name: name);
}
class Token extends Entity {
  Token(Location location, {String name, int offset, int end}) : super(location, name: name, offset: offset, end: end);
}
class Reference extends Token {
  Reference(Location location, {String name, int offset, int end}) : super(location, name: name, offset: offset, end: end);
}