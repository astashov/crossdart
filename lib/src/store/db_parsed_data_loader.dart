library crossdart.store.db_parsed_data_loader;

import 'dart:async';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/util/iterable.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/store.dart';
import 'package:crossdart/src/version.dart';
import 'package:sqljocky/sqljocky.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

var _logger = new Logger("store.load");

class DbParsedDataLoader {
  Config _config;

  DbParsedDataLoader(this._config);

  Future<ParsedData> load(Iterable<Package> packages) async {
    Map<int, Package> packagesById = groupByOne(packages, (i) => i.id);

    try {
      var parsedData = new ParsedData();

      for (var package in packages) {
        var results = (await (await _queryEntities(package)).toList());
        groupBy(results, (i) => i.r_path).forEach((String path, Iterable<Row> rows) {
          rows.forEach((Row row) {
            Package referencePackage = packagesById[row.r_package_id];
            var reference = new Reference(new Location(referencePackage, row.r_path), name: row.r_name, offset: row.r_offset, end: row.r_end);

            Package declarationPackage = packagesById[row.d_package_id];
            var location = new Location(declarationPackage, row.d_path);
            Declaration declaration;
            if (row.d_type == entityTypeIds[Declaration]) {
              declaration = new Declaration(location, name: row.d_name, offset: row.d_offset, end: row.d_end);
            } else if (row.d_type == entityTypeIds[Import]) {
              declaration = new Import(location, name: row.d_name);
            }

            _fillInParsedData(parsedData, reference, declaration);
          });
        });
      }

      return parsedData;
    } catch (exception, stackTrace) {
      _logger.severe("Exception while trying to load data from the db - ${exception}, ${stackTrace}");
      return new ParsedData();
    }
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

  Future<Results> _queryEntities(Package package) {
    return dbPool.query("""
    SELECT r.id AS 'r_id', r.name AS 'r_name', r.offset AS 'r_offset', r.end AS 'r_end', r.path AS 'r_path', r.package_id AS 'r_package_id',
           d.id AS 'd_id', d.type AS 'd_type', d.name AS 'd_name', d.offset AS 'd_offset', d.end AS 'd_end', d.path AS 'd_path', d.package_id AS 'd_package_id'
    FROM entities AS r
    INNER JOIN entities AS d ON r.declaration_id = d.id
    WHERE r.type = ${entityTypeIds[Reference]} AND r.package_id = ${package.id}
  """);
  }
}
