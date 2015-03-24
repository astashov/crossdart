#!/usr/bin/env dart

import 'dart:io';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/crossdart.dart';
import 'package:crossdart/src/service.dart';
import 'package:crossdart/src/version.dart';
import 'package:logging/logging.dart';

Logger _logger = new Logger("main");

void main(args) async {
  config = new Config.fromArgs(args);
  logging.initialize();

  var failedPackageNames = new Set<PackageInfo>();
//  var packageInfos = [
//      new PackageInfo("frappe", new Version.fromString("0.4.0+4")),
//      new PackageInfo("route", new Version.fromString("0.4.6")),
//      new PackageInfo("dnd", new Version.fromString("0.2.1"))]; //await
  var packageInfos = await getAvailablePackages();
  print(packageInfos);
//  packageInfos.forEach((packageInfo) {
//    try {
//      install(packageInfo);
//      var package = new CustomPackage(packageInfo);
//      var parsedData = parse(package);
//      generatePackageHtml(package, parsedData);
//      return package;
//    } catch(exception, stackTrace) {
//      _logger.severe("Exception while handling a package ${packageInfo.name} ${packageInfo.version}", exception, stackTrace);
//      failedPackageNames.add(packageInfo);
//    }
//  });
//  generateIndexHtml(packageInfos);
}