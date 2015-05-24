library crossdart.generator.json_generator;

import 'dart:io';
import 'dart:convert';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:path/path.dart' as p;

class JsonGenerator {
  final Environment _environment;
  final ParsedData _parsedData;
  JsonGenerator(this._environment, this._parsedData);

  void generate() {
    var file = new File(p.join(_environment.config.outputPath, "crossdart.json")).openSync(mode: FileMode.WRITE);
    var pubspecLockPath = p.join(_environment.config.projectPath, "pubspec.lock");
    var result = {};
    _parsedData.files.forEach((String absolutePath, Set<Entity> entities) {
      var relativePath = p.join("lib", entities.first.location.package.relativePath(absolutePath));
      result[relativePath] = {
        "references": _getReferencesValues(pubspecLockPath, entities).toList(),
        "declarations": _getDeclarationsValues(pubspecLockPath, entities).toList()
      };
    });
    file.writeStringSync(JSON.encode(result));
  }

  Iterable<Map<String, Object>> _getReferencesValues(String pubspecLockPath, Set<Entity> entities) {
    var references = entities.where((e) => e is Reference && e.location.package is Project).toList();
    references.sort((a, b) => Comparable.compare(a.offset, b.offset));
    return references.map((reference) {
      var declaration = _parsedData.references[reference];
      var value = {};

      value["line"] = reference.lineNumber + 1;
      value["offset"] = reference.lineOffset;
      value["length"] = reference.end - reference.offset;
      value["remotePath"] = declaration.location.remotePath(declaration.lineNumber, pubspecLockPath);
      return value;
    });
  }

  Iterable<Map<String, Object>> _getDeclarationsValues(String pubspecLockPath, Set<Entity> entities) {
    var declarations = entities.where((e) => e is Declaration && e.location.package is Project && e.offset != null).toList();
    declarations.sort((a, b) => Comparable.compare(a.offset, b.offset));
    return declarations.map((declaration) {
      var references = _parsedData.declarations[declaration];
      var value = {
        "line": declaration.lineNumber + 1,
        "offset": declaration.lineOffset,
        "length": declaration.end - declaration.offset,
      };
      value["references"] = references.map((reference) {
        return {
          "remotePath": reference.location.remotePath(reference.lineNumber, pubspecLockPath)
        };
      }).toList();
      return value;
    });
  }
}