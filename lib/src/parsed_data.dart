library crossdart.parsed_data;

import 'package:crossdart/src/entity.dart';

class ParsedData {
  Map<Declaration, Set<Reference>> declarations = {};
  Map<Reference, Declaration> references = {};
  Map<String, Set<Entity>> files = {};
  Set<Entity> tokens = new Set();
}