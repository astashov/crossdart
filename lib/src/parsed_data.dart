library crossdart.parsed_data;

import 'package:crossdart/src/entity.dart';

class ParsedData {
  Map<Declaration, Set<Reference>> declarations = {};
  Map<Reference, Declaration> references = {};
  Map<String, Set<Entity>> files = {};
  Set<Entity> tokens = new Set();

  ParsedData merge(ParsedData other) {
    var newParsedData = new ParsedData();
    var stopwatch = new Stopwatch()..start();
    declarations.forEach((Declaration declaration, Set<Reference> references) {
      if (newParsedData.declarations[declaration] == null) {
        newParsedData.declarations[declaration] = new Set();
      }
      newParsedData.declarations[declaration].addAll(references);
    });
    print("${stopwatch.elapsedMilliseconds}ms");
    stopwatch.reset();

    other.declarations.forEach((Declaration declaration, Set<Reference> references) {
      if (newParsedData.declarations[declaration] == null) {
        newParsedData.declarations[declaration] = new Set();
      }
      newParsedData.declarations[declaration].addAll(references);
    });
    print("${stopwatch.elapsedMilliseconds}ms");
    stopwatch.reset();

    newParsedData.references..addAll(references)..addAll(other.references);
    print("${stopwatch.elapsedMilliseconds}ms");
    stopwatch.reset();

    newParsedData.tokens..addAll(tokens)..addAll(other.tokens);
    print("${stopwatch.elapsedMilliseconds}ms");
    stopwatch.reset();

    files.forEach((String file, Set<Entity> entities) {
      if (newParsedData.files[file] == null) {
        newParsedData.files[file] = new Set();
      }
      newParsedData.files[file].addAll(entities);
    });
    print("${stopwatch.elapsedMilliseconds}ms");
    stopwatch.reset();

    other.files.forEach((String file, Set<Entity> entities) {
      if (newParsedData.files[file] == null) {
        newParsedData.files[file] = new Set();
      }
      newParsedData.files[file].addAll(entities);
    });
    print("${stopwatch.elapsedMilliseconds}ms");
    stopwatch.reset();

    return newParsedData;
  }
}