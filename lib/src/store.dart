library crossdart.store;

import 'dart:io';
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

// TODO: Refactor to a class

Future store(Environment environment, ParsedData parsedData) async {
  _logger.info("Starting transaction to store the package, dependencies, and all the entities...");

  var config = environment.config;
  await dbPool(environment.config).query("SET SESSION innodb_lock_wait_timeout=2000");
  final transaction = await dbPool(environment.config).startTransaction(consistent: false);
  await transaction.query("SET SESSION innodb_lock_wait_timeout=2000");

  for (final package in environment.packages) {
    await storePackage(config, package.packageInfo, package.source, package.description, transaction);
  }
  final environmentWithIds = await environment.rebuildWithPackageIds(transaction);
  await storeDependencies(environmentWithIds, environmentWithIds.package, transaction);

  final insertQuery = await transaction.prepare("""
    INSERT IGNORE INTO entities (declaration_id, type, kind, name, context_name, offset, end, line_number, line_offset, path, package_id, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  """);
  var files = [];

  _logger.info("Preparing files");

  final packages = parsedData.files.keys.map((k) => environmentWithIds.packagesByFiles[k]).toSet();

  final query = """
    SELECT DISTINCT package_id FROM entities WHERE package_id IN (${packages.map((p) => p.id).toList().join(",")})
  """;
  var existingPackageIds = (await (await transaction.query(query)).toList()).map((r) => r.package_id).toSet();

  parsedData.files.forEach((absolutePath, entities) {
    var location = new Location.fromEnvironment(environmentWithIds, absolutePath);
    if (!existingPackageIds.contains(location.package.id)) {
      files.add([absolutePath, entities]);
    }
  });

  _logger.info("Storing declarations");
  var idsByDeclarationsList = [];
  for (final absolutePath in parsedData.files.keys) {
    var entities = parsedData.files[absolutePath];
    var filteredEntities = entities.where((e) => e is Declaration);
    idsByDeclarationsList.add(await _storeDeclarations(environmentWithIds, insertQuery, absolutePath, filteredEntities, transaction));
  }

  _logger.info("\nMaking idsByDeclaration map");
  var idsByDeclarations = idsByDeclarationsList.fold({}, (memo, map) {
    memo.addAll(map);
    return memo;
  });
  _logger.info("Number of declarations - ${idsByDeclarations.length}");

  _logger.info("Storing references");
  var referencesValues = files.map((tuple) {
    var absolutePath = tuple[0];
    var entities = tuple[1];
    var filteredEntities = entities.where((e) => e is Reference);

    return _getReferencesValues(environmentWithIds, parsedData, absolutePath, filteredEntities, idsByDeclarations);
  }).expand((i) => i).toList();
  _logger.info("Executing query to store references - ${referencesValues.length}");
  if (referencesValues.length > 0) {
    await insertQuery.executeMulti(referencesValues);
  }

  _logger.info("Storing tokens");
  var tokensValues = files.map((tuple) {
    var absolutePath = tuple[0];
    var entities = tuple[1];
    var filteredEntities = entities.where((e) => e.runtimeType == Token);
    return _getTokensValues(environmentWithIds, parsedData, absolutePath, filteredEntities);
  }).expand((i) => i).toList();
  _logger.info("Executing query to store tokens - ${tokensValues.length}");
  if (tokensValues.length > 0) {
    await insertQuery.executeMulti(tokensValues);
  }
  _logger.info("Committing transaction");
  await transaction.commit();
  _logger.info("Committed");
}

List _buildValue(Config config, Entity entity, Location location, [int declarationId]) {
  return [
      declarationId,
      entity.runtimeType,
      entity.kind.toString(),
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

Future<Map<Declaration, int>> _storeDeclarations(Environment environment, Query query, String absolutePath, Iterable<Declaration> declarations, QueriableConnection conn) async {
  var location = new Location.fromEnvironment(environment, absolutePath);
  var idAndDeclaration = [];
  for (final declaration in declarations) {
    int id;
    if (declaration.id == null) {
      var value = _buildValue(environment.config, declaration, location);
      Results result = await query.execute(value);
      stdout.write(".");
      id = result.insertId;
      if (id == 0) {
        id = declaration.id;
      }
      if (id == null) {
        id = (await (await conn.query("""
          SELECT id FROM entities
          WHERE type = 'Declaration' AND offset = ${declaration.offset} AND end = ${declaration.end} AND
                path = '${location.path}' AND package_id = ${location.package.id}
        """)).toList()).first.id;
      }
    } else {
      id = declaration.id;
    }
    idAndDeclaration.add([declaration, id]);
  }
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
  return prepareExecute(config,
      "INSERT IGNORE INTO errors (package_name, package_version, error, created_at) VALUES (?, ?, ?, ?)",
      [packageInfo.name, packageInfo.version.toString(), "${error}\n${stackTrace}", config.currentDate]);
}

Future storeDependencies(Environment environment, Package package, [QueriableConnection conn]) async {
  if (conn == null) {
    conn = dbPool(environment.config);
  }
  _logger.info("Storing dependencies");
  await _storeDependencies(environment, package, conn);
  _logger.info("Storing dependencies finished");
}

Future<int> storePackage(Config config, PackageInfo packageInfo, PackageSource source, String description, [QueriableConnection conn]) async {
  if (conn == null) {
    conn = dbPool(config);
  }
  var result = await conn.prepareExecute(
      "INSERT IGNORE INTO packages (name, version, source_type, description, created_at) VALUES (?, ?, ?, ?, ?)",
      [packageInfo.name, packageInfo.version.toString(), packageSourceIds[source], description, config.currentDate]);
  return result.insertId;
}

Future _storeDependencies(Environment environment, Package package, QueriableConnection conn, [Set handledPackages]) async {
  if (handledPackages == null) {
    handledPackages = new Set();
  }
  if (!handledPackages.contains(package)) {
    handledPackages.add(package);
    for (Package dependency in package.dependencies(environment)) {
      await _storeDependencies(environment, dependency, conn, handledPackages);
      await _storeDependency(environment.config, package.id, dependency.id, conn);
    }
  }
}


Future<Results> _storeDependency(Config config, int packageId, int dependencyId, QueriableConnection conn) {
  return conn.prepareExecute(
      "INSERT IGNORE INTO packages_dependencies (package_id, dependency_id) VALUES (?, ?)",
      [packageId, dependencyId]);
}


Future<int> getPackageId(Config config, PackageInfo packageInfo, [QueriableConnection conn]) async {
  if (conn == null) {
    conn = dbPool(config);
  }
  var results = (await (await conn.query("""
    SELECT id FROM packages
    WHERE name = '${packageInfo.name}' AND version = '${packageInfo.version}'
  """)).toList());
  if (results.isNotEmpty) {
    return results.first.id;
  } else {
    return null;
  }
}
