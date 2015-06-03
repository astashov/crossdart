library crossdart.store;

import 'dart:async';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/config.dart';
import 'package:sqljocky/sqljocky.dart';
import 'package:logging/logging.dart';

var _logger = new Logger("store");

Map<Type, int> entityTypeIds = {
  Reference: 1,
  Declaration: 2,
  Import: 3,
  Token: 4
};

Map<EntityKind, int> entityKindIds = {
  EntityKind.CLASS: 1,
  EntityKind.METHOD: 2,
  EntityKind.LOCAL_VARIABLE: 3,
  EntityKind.FUNCTION: 4,
  EntityKind.PROPERTY_ACCESSOR: 5,
  EntityKind.CONSTRUCTOR: 6,
  EntityKind.FIELD: 7,
  EntityKind.FUNCTION_TYPE_ALIAS: 8,
  EntityKind.TOP_LEVEL_VARIABLE: 9
};

// TODO: Refactor to a class

Future store(Environment environment, ParsedData parsedData) async {
  var config = environment.config;
  return dbPool(config).prepare("""
    INSERT IGNORE INTO entities (declaration_id, type, kind, name, context_name, offset, end, line_number, line_offset, path, package_id, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  """).then((query) async {
    var files = [];

    _logger.info("Preparing files");

    var packages = parsedData.files.keys.map((k) => environment.packagesByFiles[k]).toSet();
    var existingPackageIds = (await (await dbPool(config).query("""
      SELECT DISTINCT package_id FROM entities WHERE package_id IN (${packages.map((p) => p.id).toList().join(",")})
    """)).toList()).map((r) => r.package_id).toSet();

    parsedData.files.forEach((absolutePath, entities) {
      var location = new Location.fromEnvironment(environment, absolutePath);
      if (!existingPackageIds.contains(location.package.id)) {
        files.add([absolutePath, entities]);
      }
    });

    _logger.info("Storing declarations");
    var idsByDeclarationsList = await Future.wait(parsedData.files.keys.map((absolutePath) async {
      var entities = parsedData.files[absolutePath];
      var filteredEntities = entities.where((e) => e is Declaration);
      return await _storeDeclarations(environment, query, absolutePath, filteredEntities);
    }));

    _logger.info("Making idsByDeclaration map");
    var idsByDeclarations = idsByDeclarationsList.fold({}, (memo, map) {
      memo.addAll(map);
      return memo;
    });

    _logger.info("Storing references");
    var referencesValues = files.map((tuple) {
      var absolutePath = tuple[0];
      var entities = tuple[1];
      var filteredEntities = entities.where((e) => e is Reference);

      return _getReferencesValues(environment, parsedData, absolutePath, filteredEntities, idsByDeclarations);
    }).expand((i) => i).toList();
    _logger.info("Executing query to store references");
    if (referencesValues.length > 0) {
      await query.executeMulti(referencesValues);
    }

    _logger.info("Storing tokens");
    var tokensValues = files.map((tuple) {
      var absolutePath = tuple[0];
      var entities = tuple[1];
      var filteredEntities = entities.where((e) => e.runtimeType == Token);
      return _getTokensValues(environment, parsedData, absolutePath, filteredEntities);
    }).expand((i) => i).toList();
    _logger.info("Executing query to store tokens");
    if (tokensValues.length > 0) {
      await query.executeMulti(tokensValues);
    }
  });
}

List _buildValue(Config config, Entity entity, Location location, [int declarationId]) {
  return [
      declarationId,
      entityTypeIds[entity.runtimeType],
      entityKindIds[entity.kind],
      entity.name,
      entity.contextName,
      entity.offset,
      entity.end,
      entity.lineNumber,
      entity.lineOffset,
      location.path,
      location.package.id,
      config.currentDate];
}

Future<Map<Declaration, int>> _storeDeclarations(Environment environment, Query query, String absolutePath, Iterable<Declaration> declarations) async {
  var location = new Location.fromEnvironment(environment, absolutePath);
  var idAndDeclaration = await Future.wait(declarations.map((declaration) async {
    var value = _buildValue(environment.config, declaration, location);
    Results result = await query.execute(value);
    var id = result.insertId;
    if (id == 0) {
      id = declaration.id;
    }
    if (id == null) {
      id = (await (await dbPool(environment.config).query("""
        SELECT id FROM entities
        WHERE type = ${entityTypeIds[Declaration]} AND offset = ${declaration.offset} AND end = ${declaration.end} AND
              path = '${location.path}' AND package_id = ${location.package.id}
      """)).toList()).first.id;
    }
    return [declaration, id];
  }));
  return idAndDeclaration.fold({}, (memo, values) {
    memo[values[0]] = values[1];
    return memo;
  });
}

List<List> _getReferencesValues(Environment environment, ParsedData parsedData, String absolutePath, Iterable<Reference> references, [Map<Declaration, int> idsByDeclarations]) {
  var location = new Location.fromEnvironment(environment, absolutePath);
  return references.map((reference) {
    var declaration = parsedData.references[reference];
    var declarationId = idsByDeclarations[declaration];
    return _buildValue(environment.config, reference, location, declarationId);
  }).toList();
}

List<List> _getTokensValues(Environment environment, ParsedData parsedData, String absolutePath, Iterable<Token> tokens) {
  var location = new Location.fromEnvironment(environment, absolutePath);
  return tokens.map((token) {
    return _buildValue(environment.config, token, location);
  }).toList();
}


Future storeError(Config config, PackageInfo packageInfo, Object error, StackTrace stackTrace) async {
  return dbPool(config).prepareExecute(
      "INSERT IGNORE INTO errors (package_name, package_version, error, created_at) VALUES (?, ?, ?, ?)",
      [packageInfo.name, packageInfo.version.toString(), "${error}\n${stackTrace}", config.currentDate]);
}

Future storeDependencies(Environment environment, Package package) async {
  _logger.info("Storing dependencies");
  var transaction = await dbPool(environment.config).startTransaction(consistent: true);
  await _storeDependencies(environment, package);
  await transaction.commit();
  _logger.info("Storing dependencies finished");
}

Future<int> storePackage(Config config, PackageInfo packageInfo, PackageSource source, String description) async {
  var result = await dbPool(config).prepareExecute(
      "INSERT IGNORE INTO packages (name, version, source_type, description, created_at) VALUES (?, ?, ?, ?, ?)",
      [packageInfo.name, packageInfo.version.toString(), packageSourceIds[source], description, config.currentDate]);
  return result.insertId;
}

Future _storeDependencies(Environment environment, Package package, [Set handledPackages]) async {
  if (handledPackages == null) {
    handledPackages = new Set();
  }
  if (!handledPackages.contains(package)) {
    handledPackages.add(package);
    for (Package dependency in package.dependencies(environment)) {
      await _storeDependencies(environment, dependency, handledPackages);
      await _storeDependency(environment.config, package.id, dependency.id);
    }
  }
}


Future<Results> _storeDependency(Config config, int packageId, int dependencyId) {
  return dbPool(config).prepareExecute(
      "INSERT IGNORE INTO packages_dependencies (package_id, dependency_id) VALUES (?, ?)",
      [packageId, dependencyId]);
}


Future<int> getPackageId(Config config, PackageInfo packageInfo) async {
  var results = (await (await dbPool(config).query("""
    SELECT id FROM packages
    WHERE name = '${packageInfo.name}' AND version = '${packageInfo.version}'
  """)).toList());
  if (results.isNotEmpty) {
    return results.first.id;
  } else {
    return null;
  }
}
