library crossdart.store.db_package_loader;

import 'dart:async';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/util/iterable.dart';
import 'package:crossdart/src/util/map.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/store.dart';
import 'package:crossdart/src/entity.dart';
import 'package:sqljocky/sqljocky.dart';
import 'package:logging/logging.dart';

var _logger = new Logger("store.load");

class DbPackageLoader {
  Config _config;

  DbPackageLoader(this._config);

  Future<bool> doesPackageExist(PackageInfo packageInfo) async {
    var results = await (await dbPool.query("""
        SELECT p.id FROM packages AS p WHERE p.name = '${packageInfo.name}' AND p.version = '${packageInfo.version}' 
    """)).toList();
    return results.isNotEmpty;
  }

  Future<Iterable<Package>> getAllPackages() async {
    var results = await (await dbPool.query("""
        SELECT DISTINCT p.id, p.name, p.version, p.source_type, p.description, e.path FROM packages AS p
        INNER JOIN entities AS e ON p.id = e.package_id 
    """)).toList();
    var resultsGroupedById = groupBy(results, (r) => r.id);
    return fold([], resultsGroupedById, (List<Package> memo, int id, Iterable<Row> rows) {
      var row = rows.first;

      var packageInfo = new PackageInfo(row.name, new Version(row.version));
      var source = key(packageSourceIds, row.source_type);
      if (packageInfo.name == "sdk") {
        memo.add(new Sdk(_config, row.id, packageInfo, source, row.description.toString(), rows.map((r) => r.path)));
      } else {
        memo.add(new CustomPackage(_config, row.id, packageInfo, source, row.description.toString(), rows.map((r) => r.path)));
      }
      return memo;
    });
  }

  Future<Iterable<Package>> getPackageWithDependencies(PackageInfo initialPackageInfo) async {
    var initialPackage = await buildFromDatabase(_config, initialPackageInfo);
    var sdkPackage = await buildSdkFromFileSystem(_config, new PackageInfo.buildSdk(_config));
    var dependencies = (await _getAllDependencies(initialPackage)).toList();
    if (!dependencies.contains(sdkPackage)) {
      dependencies.add(sdkPackage);
    }
    return dependencies;
  }

  Future<Iterable<Package>> _getAllDependencies(Package package, [Set<Package> handledPackages]) async {
    if (handledPackages == null) {
      handledPackages = new Set.from([]);
    }
    if (!handledPackages.contains(package)) {
      handledPackages.add(package);
      var dependencies = await _getDependencies(package);
      for (var pi in dependencies) {
        await _getAllDependencies(pi, handledPackages);
      }
    }
    return handledPackages;
  }

  Future<Iterable<Package>> _getDependencies(Package package) async {
    var results = await (await dbPool.query("""
        SELECT DISTINCT p.name, p.version
            FROM entities AS r
            INNER JOIN entities AS d ON r.declaration_id = d.id
            INNER JOIN packages AS p ON d.package_id = p.id 
            WHERE r.type = ${entityTypeIds[Reference]} AND r.package_id = ${package.id}
    """)).toList();

    return Future.wait(results.map((r) async {
      var packageInfo = new PackageInfo(r.name, new Version(r.version));
      return await buildFromDatabase(_config, packageInfo);
    }));
  }
}
