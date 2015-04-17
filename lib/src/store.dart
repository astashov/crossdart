library crossdart.store;

import 'dart:async';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/db_pool.dart';
import 'package:sqljocky/sqljocky.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

var _logger = new Logger("store");

Map<Type, int> entityTypeIds = {
  Reference: 1,
  Declaration: 2,
  Import: 3
};

// TODO: Refactor to a class

Future store(Environment environment, ParsedData parsedData) async {
  return dbPool.prepare("""
    INSERT IGNORE INTO entities (declaration_id, type, name, offset, end, path, package_id)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  """).then((query) async {
    var files = [];
    _logger.info("Preparing files");
    parsedData.files.forEach((filePath, entities) {
      files.add([filePath, entities]);
    });

    _logger.info("Storing declarations");
    var idsByDeclarationsList = await Future.wait(files.map((tuple) async {
      var filePath = tuple[0];
      var entities = tuple[1];
      var filteredEntities = entities.where((e) => e is Declaration);
      return await _storeDeclarations(environment, query, filePath, filteredEntities);
    }));

    _logger.info("Making idsByDeclaration map");
    var idsByDeclarations = idsByDeclarationsList.fold({}, (memo, map) {
      memo.addAll(map);
      return memo;
    });

    _logger.info("Storing references");
    return await Future.wait(files.map((tuple) {
      var filePath = tuple[0];
      var entities = tuple[1];
      var filteredEntities = entities.where((e) => e is Reference);
      return _storeReferences(environment, parsedData, query, filePath, filteredEntities, idsByDeclarations);
    }));
  });
}

List _buildValue(Entity entity, Location location, [int declarationId]) {
  return [
      declarationId,
      entityTypeIds[entity.runtimeType],
      entity.name,
      entity.offset,
      entity.end,
      location.path,
      location.package.id];
}

Future<Map<Declaration, int>> _storeDeclarations(Environment environment, Query query, String filePath, Iterable<Declaration> declarations) async {
  var location = new Location.fromEnvironment(environment, filePath);
  var idAndDeclaration = await Future.wait(declarations.map((declaration) async {
    var value = _buildValue(declaration, location);
    Results result = await query.execute(value);
    var id = result.insertId;
    return [declaration, id];
  }));
  return idAndDeclaration.fold({}, (memo, values) {
    memo[values[0]] = values[1];
    return memo;
  });
}

Future _storeReferences(Environment environment, ParsedData parsedData, Query query, String filePath, Iterable<Reference> references, [Map<Declaration, int> idsByDeclarations]) {
  var location = new Location.fromEnvironment(environment, filePath);
  var values = references.map((reference) {
    var declaration = parsedData.references[reference];
    var declarationId = idsByDeclarations[declaration];
    return _buildValue(reference, location, declarationId);
  }).toList();
  return Future.wait(values.map((value) {
    return query.execute(value);
  }));
}

Future storeError(PackageInfo packageInfo, Object error, StackTrace stackTrace) async {
  var id = await getPackageId(packageInfo);
  return dbPool.prepareExecute(
      "INSERT IGNORE INTO errors (package_id, error) VALUES (?, ?)",
      [id, "${error}\n${stackTrace}"]);
}

Future storeDependencies(Environment environment, Package package, [Set handledPackages]) async {
  if (handledPackages == null) {
    handledPackages = new Set();
  }
  if (!handledPackages.contains(package)) {
    handledPackages.add(package);
    for (Package dependency in package.dependencies(environment)) {
      await storeDependencies(environment, dependency, handledPackages);
      await _storeDependency(package.id, dependency.id);
    }
  }
}

Future<int> storePackage(PackageInfo packageInfo, PackageSource source, String description) async {
  var result = await dbPool.prepareExecute(
      "INSERT IGNORE INTO packages (name, version, source_type, description) VALUES (?, ?, ?, ?)",
      [packageInfo.name, packageInfo.version.toString(), packageSourceIds[source], description]);
  return result.insertId;
}

Future<Results> _storeDependency(int packageId, int dependencyId) {
  print("Inserting ${packageId}, ${dependencyId}");
  return dbPool.prepareExecute(
      "INSERT IGNORE INTO packages_dependencies (package_id, dependency_id) VALUES (?, ?)",
      [packageId, dependencyId]);
}


Future<int> getPackageId(PackageInfo packageInfo) async {
  var results = (await (await dbPool.query("""
    SELECT id FROM packages
    WHERE name = '${packageInfo.name}' AND version = '${packageInfo.version}'
  """)).toList());
  if (results.isNotEmpty) {
    return results.first.id;
  } else {
    return null;
  }
}