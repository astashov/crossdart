library crossdart.store.db_parsed_data_loader;

import 'dart:async';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/util/iterable.dart';
import 'package:sqljocky/sqljocky.dart';
import 'package:logging/logging.dart';

var _logger = new Logger("store.load");

class DbParsedDataLoader {
  Config _config;

  DbParsedDataLoader(this._config);

  ParsedData __sdkParsedData;
  Future<ParsedData> _sdkParsedData(Sdk package, Map<int, Package> packagesById) async {
    if (__sdkParsedData == null) {
      __sdkParsedData = new ParsedData();
      _logger.info("Loading parsed data from the database for the package ${package.packageInfo}");
      await _loadReferences(package, __sdkParsedData, packagesById);
      if (__sdkParsedData.files.isEmpty) {
        __sdkParsedData = null;
      }
    }
    return __sdkParsedData == null ? new ParsedData() : __sdkParsedData;
  }

  Future<ParsedData> load(Iterable<Package> packages) async {
    Map<int, Package> packagesById = groupByOne(packages, (i) => i.id);
    try {
      ParsedData parsedData;
      Sdk sdkPackage = packages.firstWhere((p) => p is Sdk, orElse: () => null);
      if (sdkPackage != null) {
        parsedData = (await _sdkParsedData(sdkPackage, packagesById)).copy();
      } else {
        parsedData = new ParsedData();
      }
      for (var package in packages) {
        _logger.info("Loading parsed data from the database for the package ${package.packageInfo}");
        if (package is! Sdk) {
          await _loadReferences(package, parsedData, packagesById);
        }
      }

      return parsedData;
    } catch (exception, stackTrace) {
      _logger.severe("Exception while trying to load data from the db - ${exception}, ${stackTrace}");
      return new ParsedData();
    }
  }

  Future _loadReferences(Package package, ParsedData parsedData, Map<int, Package> packagesById) async {
    _logger.info("Loading previous references from the database");
    var referenceResults = (await (await _queryReferences(package)).toList());

    groupBy(referenceResults, (i) => i.r_path).forEach((String path, Iterable<Row> rows) {
      rows.forEach((Row row) {
        Package referencePackage = packagesById[row.r_package_id];
        Package declarationPackage = packagesById[row.d_package_id];

        if (referencePackage != null && declarationPackage != null) {
          var reference = new Reference(new Location(_config, referencePackage, row.r_path), name: row.r_name, offset: row.r_offset, end: row.r_end, id: row.r_id);
          var location = new Location(_config, declarationPackage, row.d_path);
          Declaration declaration;
          if (row.d_type == "Declaration") {
            declaration = new Declaration(location, name: row.d_name, offset: row.d_offset, end: row.d_end, id: row.d_id);
          } else if (row.d_type == "Import") {
            declaration = new Import(location, name: row.d_name, id: row.d_id);
          }

          _fillInParsedData(parsedData, reference, declaration);
        }
      });
    });
  }

  void _fillInParsedData(ParsedData parsedData, Reference reference, Declaration declaration) {
    parsedData.references[reference] = declaration;

    if (parsedData.declarations[declaration] == null) {
      parsedData.declarations[declaration] = new Set();
    }
    parsedData.declarations[declaration].add(reference);

    if (parsedData.files[reference.location.file] == null) {
      parsedData.files[reference.location.file] = new Set();
    }
    parsedData.files[reference.location.file].add(reference);

    if (parsedData.files[declaration.location.file] == null) {
      parsedData.files[declaration.location.file] = new Set();
    }
    parsedData.files[declaration.location.file].add(declaration);
  }

  Future<Results> _queryReferences(Package package) {
    return dbPool(_config).query("""
      SELECT r.id AS 'r_id', r.name AS 'r_name', r.offset AS 'r_offset', r.end AS 'r_end', r.path AS 'r_path', r.package_id AS 'r_package_id',
             d.id AS 'd_id', d.type AS 'd_type', d.name AS 'd_name', d.offset AS 'd_offset', d.end AS 'd_end', d.path AS 'd_path', d.package_id AS 'd_package_id'
      FROM entities AS r
      INNER JOIN entities AS d ON r.declaration_id = d.id
      WHERE r.type = 'Reference' AND r.package_id = ${package.id}
    """);
  }
}
