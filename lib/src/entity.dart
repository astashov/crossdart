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
    String contents = cache.fileContents(location.file);
    return new RegExp("(\r\n|\n|\r)", multiLine: true).allMatches(contents.substring(0, offset)).length;
  }

  Location _buildLocation(String file, Element element) {
    var package;
    if (element.source.isInSystemLibrary) {
      package = sdk;
    } else {
      package = packages.firstWhere((package) => package.doesContainFile(file));
    }

    return new Location(file, package);
  }

  Entity(AstNode node, Element element, String file) {
    this.name = element.displayName;
    this.offset = node.offset;
    this.end = node.end;
    this.location = _buildLocation(file, element);
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
  Declaration(AstNode node, Element element) : super(node, element, element.source.fullName);
}
class Reference extends Entity {
  Reference(AstNode node, Element element, String file) : super(node, element, file);
}