#!/usr/bin/env dart

import 'dart:async';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/store/db_parsed_data_loader.dart';
import 'package:crossdart/src/store/db_package_loader.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/crossdart.dart';
import 'package:crossdart/src/db_pool.dart';
import 'package:logging/logging.dart';

Logger _logger = new Logger("generate_html");

Future main(args) async {
  var config = new Config.fromArgs(args);
  logging.initialize();

  await runHtmlGenerator(config);

  dbPool.close();
}

Future runHtmlGenerator(Config config) async {
  var index = 0;
  var packageLoader = new DbPackageLoader(config);
  var allPackages = await packageLoader.getAllPackages();

  for (Package aPackage in allPackages) {
    var packageInfo = aPackage.packageInfo;
    _logger.info("Generating HTML for package ${packageInfo.name} (${packageInfo.version}) - ${index}/${allPackages.length}");
    try {
      var packages = await (packageLoader.getPackageWithDependencies(packageInfo));
      var parsedData = await (new DbParsedDataLoader(config).load(packages));

      generatePackageHtml(config, packages, parsedData);
    } catch(exception, stackTrace) {
      _logger.severe("Exception while handling a package ${packageInfo.name} ${packageInfo.version}", exception, stackTrace);
    }
    index += 1;
  };
  generateIndexHtml(config);
}
