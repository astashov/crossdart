library crossdart.entity;

import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/cache.dart';
import 'package:crossdart/src/util.dart';

abstract class Entity {
  final Location location;
  final String name;
  final String contextName;
  final int offset;
  final int end;

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

  int _lineOffset;
  int get lineOffset {
    if (offset != null) {
      if (_lineOffset == null) {
        _lineOffset = cache.lineOffset(location.file, offset);
      }
      return _lineOffset;
    } else {
      return null;
    }
  }

  Entity(this.location, {this.name, this.contextName, this.offset, this.end});

  int get hashCode => hash([this.runtimeType, location, name, offset, end]);

  bool operator ==(other) {
    return (other.runtimeType == this.runtimeType)
      && location == other.location
      && name == other.name
      && offset == other.offset
      && end == other.end;
  }

  String toString() {
    return "<${runtimeType} ${toMap()}>";
  }

  Map<String, Object> toMap() {
    return {"location": location, "name": name, "offset": offset, "end": end};
  }
}

class Declaration extends Entity {
  Declaration(Location location, {String name, String contextName, int offset, int end})
      : super(location, name: name, contextName: contextName, offset: offset, end: end);
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