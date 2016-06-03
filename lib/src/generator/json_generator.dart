library crossdart.generator.json_generator;

import 'dart:io';
import 'dart:convert';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:path/path.dart' as p;
import 'package:logging/logging.dart';

var _logger = new Logger("json_generator");

class JsonGenerator {
  final Environment _environment;
  final ParsedData _parsedData;
  JsonGenerator(this._environment, this._parsedData);

  void generate({bool isForGithub: false}) {
    _logger.info("Generating JSON output");
    new Directory(_environment.config.output).createSync(recursive: true);
    var file = new File(p.join(_environment.config.output, "crossdart.json")).openSync(mode: FileMode.WRITE);
    var pubspecLockPath = p.join(_environment.config.input, "pubspec.lock");
    var result = {};
    _parsedData.files.forEach((String absolutePath, Set<Entity> entities) {
      String relativePath;
      if (_environment.package is Sdk) {
        relativePath = entities.first.location.package.relativePath(absolutePath);
      } else {
        relativePath = p.join("lib", entities.first.location.package.relativePath(absolutePath));
      }
      result[relativePath] = {
        "references": _getReferencesValues(pubspecLockPath, entities, _environment.package is Sdk, isForGithub).toList()
      };
      if (isForGithub) {
        result[relativePath]["declarations"] = _getDeclarationsValues(pubspecLockPath, entities, _environment.package is Sdk).toList();
      }
    });
    _logger.info("Saving JSON output to ${file.path}");
    file.writeStringSync(JSON.encode(result));
  }

  Iterable<Map<String, Object>> _getReferencesValues(String pubspecLockPath, Set<Entity> entities, bool isSdk, bool isForGithub) {
    var references = entities.where((e) {
      return e is Reference && (isSdk ? e.location.package is Sdk : e.location.package is Project);
    }).toList();
    references.sort((a, b) => Comparable.compare(a.offset, b.offset));
    return references.map((reference) {
      var declaration = _parsedData.references[reference];
      var value = {};

      if (isForGithub) {
        value["line"] = reference.lineNumber + 1;
        value["offset"] = reference.lineOffset;
        value["length"] = reference.end - reference.offset;
        value["remotePath"] = declaration.location.githubRemotePath(declaration.lineNumber, pubspecLockPath, isSdk);
      } else {
        value["offset"] = reference.offset;
        value["end"] = reference.end;
        value["remotePath"] = declaration.location.crossdartRemotePath(declaration.lineNumber, pubspecLockPath, isSdk);
      }
      return value;
    });
  }

  Iterable<Map<String, Object>> _getDeclarationsValues(String pubspecLockPath, Set<Entity> entities, bool isSdk) {
    var declarations = entities.where((e) {
      return e is Declaration && (isSdk ? e.location.package is Sdk : e.location.package is Project) && e.offset != null;
    }).toList();
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
          "remotePath": reference.location.githubRemotePath(reference.lineNumber, pubspecLockPath, isSdk)
        };
      }).toList();
      return value;
    });
  }
}