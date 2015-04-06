library crossdart.store.db_package_loader;

import 'dart:async';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/util/iterable.dart';
import 'package:crossdart/src/util/map.dart';
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

class DbPackageLoader {
  Config _config;

  DbPackageLoader(this._config);

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
        memo.add(new Sdk(_config, row.id, packageInfo, source, row.description, rows.map((r) => r.path)));
      } else {
        memo.add(new CustomPackage(_config, row.id, packageInfo, source, row.description, rows.map((r) => r.path)));
      }
      return memo;
    });
  }

  Future<Iterable<Package>> getPackageWithDependencies(PackageInfo initialPackageInfo) async {
    var initialPackage = await buildFromDatabase(_config, initialPackageInfo);
    var sdkPackage = await buildSdkFromFileSystem(_config, new PackageInfo.buildSdk(_config));
    var dependencies = await _getAllDependencies(initialPackage);
    return dependencies.toList()..add(sdkPackage);
  }

  Future<Iterable<Package>> _getAllDependencies(Package package, [Set<Package> handledPackages]) async {
    if (handledPackages == null) {
      handledPackages = new Set.from([]);
    }
    if (!handledPackages.contains(package)) {
      handledPackages.add(package);
      var dependencies = await _getDependencies(package);
      dependencies.forEach((pi) => _getAllDependencies(pi, handledPackages));
    }
    return handledPackages;
  }

  Future<Iterable<Package>> _getDependencies(Package package) async {
    var results = await (await dbPool.query("""
        SELECT name, version FROM packages_dependencies AS pd
        INNER JOIN packages AS p ON p.id = pd.dependency_id 
        WHERE pd.package_id = ${package.id}
    """)).toList();

    return Future.wait(results.map((r) async {
      var packageInfo = new PackageInfo(r.name, new Version(r.version));
      return await buildFromDatabase(_config, packageInfo);
    }));
  }
}
