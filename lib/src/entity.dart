library crossdart.entity;

import 'dart:io';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/element.dart';

import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/cache.dart';
import 'package:crossdart/src/util.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';

abstract class Entity {
  Location location;
  String name;
  int offset;
  int end;

  int get lineNumber {
    if (offset != null) {
      String contents = cache.fileContents(location.file);
      return new RegExp("(\r\n|\n|\r)", multiLine: true).allMatches(contents.substring(0, offset)).length;
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