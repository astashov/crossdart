library crossdart.parsed_data;

import 'package:crossdart/src/entity.dart';

class ParsedData {
  Map<Declaration, Set<Reference>> declarations = {};
  Map<Reference, Declaration> references = {};
  Map<String, Set<Entity>> files = {};

  ParsedData copy() {
    var data = new ParsedData();
    declarations.forEach((declaration, references) {
      data.declarations[declaration] = new Set.from(references);
    });

    data.references = new Map.from(references);

    files.forEach((path, entities) {
      data.files[path] = new Set.from(entities);
    });

    return data;
  }
}