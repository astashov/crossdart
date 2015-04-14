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
    var output = {};
    _parsedData.files.forEach((String absolutePath, Set<Entity> entities) {
      var references = entities.where((e) => e is Reference && e.location.package is Project).toList();
      references.sort((a, b) => Comparable.compare(a.offset, b.offset));
      references.forEach((reference) {
        var declaration = _parsedData.references[reference];
        var value = {};
        value["line"] = reference.lineNumber + 1;
        value["offset"] = reference.lineOffset;
        value["length"] = reference.end - reference.offset;
        value["remotePath"] = declaration.location.remotePath(declaration.lineNumber);
        var relativePath = reference.location.package.relativePath(absolutePath);
        if (output[relativePath] == null) {
          output[relativePath] = [];
        }
        output[relativePath].add(value);
      });
    });
    file.writeStringSync(JSON.encode(output));
  }
}