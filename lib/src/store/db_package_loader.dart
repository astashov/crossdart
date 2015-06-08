library crossdart.store.db_package_loader;

import 'dart:async';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/util/iterable.dart';
import 'package:crossdart/src/util/map.dart';
import 'package:crossdart/src/package_info.dart';
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
    var results = await (await dbPool(_config).query("""
        SELECT * FROM packages AS p WHERE p.name = '${packageInfo.name}' AND p.version = '${packageInfo.version}' 
    """)).toList();
    return results.isNotEmpty;
  }

  Future<Iterable<Package>> getAllPackages() async {
    var results = await (await dbPool(_config).query("""
        SELECT DISTINCT p.id, p.name, p.version, p.source_type, p.description, e.path FROM packages AS p
        INNER JOIN entities AS e ON p.id = e.package_id 
    """)).toList();
    var resultsGroupedById = groupBy(results, (r) => r.id);
    return fold([], resultsGroupedById, (List<Package> memo, int id, Iterable<Row> rows) {
      var row = rows.first;

      var source = key(packageSourceIds, row.source_type);
      var packageInfo = new PackageInfo(row.name, new Version(row.version), id: row.id, source: source);
      if (packageInfo.name == "sdk") {
        memo.add(new Sdk(_config, packageInfo, row.description.toString(), rows.map((r) => r.path)));
      } else {
        memo.add(new CustomPackage(_config, packageInfo, row.description.toString(), rows.map((r) => r.path)));
      }
      return memo;
    });
  }

  Future<Iterable<PackageInfo>> getAllPackageInfos([DateTime dateTime]) async {
    var query = "SELECT DISTINCT p.name, p.version, p.id, p.source_type FROM packages AS p";
    if (dateTime != null) {
      query += " WHERE p.created_at > ?";
    }
    var values = dateTime != null ? [dateTime] : [];
    var results = await (await dbPool(_config).prepareExecute(query, values)).toList();
    return results.map((Row r) {
      return new PackageInfo(r.name, new Version(r.version), id: r.id, source: key(packageSourceIds, r.source_type));
    });
  }

  Future<Iterable<PackageInfo>> getPackageInfoDependencies(PackageInfo packageInfo) async {
    _logger.info("Loading package with dependencies $packageInfo");
    var dependencies = (await _getAllPackageInfoDependencies(packageInfo)).toList();
    if (!dependencies.contains(new PackageInfo.buildSdk(_config))) {
      dependencies.add(new PackageInfo.buildSdk(_config));
    }
    return dependencies;
  }

  Future<Iterable<Package>> getPackageWithDependencies(PackageInfo initialPackageInfo) async {
    _logger.info("Loading package with dependencies $initialPackageInfo");
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
      for (var p in dependencies) {
        await _getAllDependencies(p, handledPackages);
      }
    }
    return handledPackages;
  }

  Future<Iterable<PackageInfo>> _getAllPackageInfoDependencies(PackageInfo packageInfo, [Set<PackageInfo> handledPackageInfos]) async {
    if (handledPackageInfos == null) {
      handledPackageInfos = new Set.from([]);
    }
    if (!handledPackageInfos.contains(packageInfo)) {
      handledPackageInfos.add(packageInfo);
      var dependencies = await _getPackageInfoDependencies(packageInfo);
      for (var pi in dependencies) {
        await _getAllPackageInfoDependencies(pi, handledPackageInfos);
      }
    }
    return handledPackageInfos;
  }

  Future<Iterable<PackageInfo>> _getPackageInfoDependencies(PackageInfo packageInfo, [Set<PackageInfo> handledPackages]) async {
    var results = await (await dbPool(_config).query("""
        SELECT DISTINCT p2.name, p2.version, p2.id, p2.source_type FROM packages AS p1
            INNER JOIN packages_dependencies AS pd ON p1.id = pd.package_id
            INNER JOIN packages AS p2 ON p2.id = pd.dependency_id
            WHERE p1.name = '${packageInfo.name}' AND p1.version = '${packageInfo.version}'
    """)).toList();

    return results.map((r) => new PackageInfo(r.name, new Version(r.version), id: r.id, source: key(packageSourceIds, r.source_type)));
  }

  Future<Iterable<Package>> _getDependencies(Package package) async {
    var results = await (await dbPool(_config).query("""
        SELECT DISTINCT p.name, p.version, p.id, p.source_type
            FROM entities AS r
            INNER JOIN entities AS d ON r.declaration_id = d.id
            INNER JOIN packages AS p ON d.package_id = p.id 
            WHERE r.type = ${entityTypeIds[Reference]} AND r.package_id = ${package.id}
    """)).toList();

    return Future.wait(results.map((r) async {
      var packageInfo = new PackageInfo(
          r.name, new Version(r.version), id: r.id, source: key(packageSourceIds, r.source_type));
      return await buildFromDatabase(_config, packageInfo);
    }));
  }
}
