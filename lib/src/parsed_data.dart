library crossdart.parsed_data;

import 'package:crossdart/src/entity.dart';

class ParsedData {
  Map<Declaration, Set<Reference>> declarations = {};
  Map<Reference, Declaration> references = {};
  Map<String, Set<Entity>> files = {};

  ParsedData merge(ParsedData other) {
    var newParsedData = new ParsedData();
    declarations.forEach((Declaration declaration, Set<Reference> references) {
      if (newParsedData.declarations[declaration] == null) {
        newParsedData.declarations[declaration] = new Set();
      }
      newParsedData.declarations[declaration].addAll(references);
    });

    other.declarations.forEach((Declaration declaration, Set<Reference> references) {
      if (newParsedData.declarations[declaration] == null) {
        newParsedData.declarations[declaration] = new Set();
      }
      newParsedData.declarations[declaration].addAll(references);
    });

    newParsedData.references..addAll(references)..addAll(other.references);

    files.forEach((String file, Set<Entity> entities) {
      if (newParsedData.files[file] == null) {
        newParsedData.files[file] = new Set();
      }
      newParsedData.files[file].addAll(entities);
    });

    other.files.forEach((String file, Set<Entity> entities) {
      if (newParsedData.files[file] == null) {
        newParsedData.files[file] = new Set();
      }
      newParsedData.files[file].addAll(entities);
    });

    return newParsedData;
  }
}