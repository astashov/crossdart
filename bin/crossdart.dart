#!/usr/bin/env dart

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/crossdart.dart';
import 'package:crossdart/src/service.dart';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/store.dart';
import 'package:logging/logging.dart';
import 'package:crossdart/src/db_pool.dart';

Logger _logger = new Logger("main");

Future main(args) async {
  config = new Config.fromArgs(args);
  logging.initialize();

  var packageInfos = [
      new PackageInfo("frappe", new Version("0.4.0+4"))
      //new PackageInfo("route", new Version.fromString("0.4.6")),
      //new PackageInfo("dnd", new Version.fromString("0.2.1"))
      ];
//  List<PackageInfo> packageInfos = (await getUpdatedPackages()).toList();
//  var erroredPackageInfos = await dbPool.query("SELECT package_name, package_version FROM errors");
//  erroredPackageInfos = (await erroredPackageInfos.toList()).map((p) {
//    return new PackageInfo(p.package_name, new Version(p.package_version));
//  });
//  erroredPackageInfos.forEach((packageInfo) {
//    packageInfos.remove(packageInfo);
//  });
//  getGeneratedPackageInfos().expand((i) => i).forEach((packageInfo) {
//    packageInfos.remove(packageInfo);
//  });

  var index = 0;
  for (PackageInfo packageInfo in packageInfos) {
    _logger.info("Handling package ${packageInfo.name} (${packageInfo.version}) - ${index}/${packageInfos.length}");
    try {
      resetPackagesByFiles();
      //install(packageInfo);
      var package = new CustomPackage(packageInfo);
      var parsedData = await parse(package);
      generatePackageHtml(package, parsedData);
      await store(parsedData);
    } catch(exception, stackTrace) {
      _logger.severe("Exception while handling a package ${packageInfo.name} ${packageInfo.version}", exception, stackTrace);
      await storeError(packageInfo, exception, stackTrace);
    }
    index += 1;
  };
  dbPool.close();
  generateIndexHtml();
}