#!/usr/bin/env dart

library generate_packages_html;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/args.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/store/db_parsed_data_loader.dart';
import 'package:crossdart/src/store/db_package_loader.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:logging/logging.dart';
import 'package:crossdart/src/html_package_generator.dart';
import 'package:crossdart/src/html_index_generator.dart';

Logger _logger = new Logger("generate_html");

Future main(args) async {
  var generatePackagesHtml = new GeneratePackagesHtmlArgs(args);
  if (!generatePackagesHtml.runChecks()) {
    return;
  }
  var results = generatePackagesHtml.results;

  var config = new Config(
      sdkPath: new File(results[Config.SDK_PATH]).resolveSymbolicLinksSync(),
      packagesPath: new File(results[Config.PACKAGES_PATH]).resolveSymbolicLinksSync(),
      outputPath: new File(results[Config.OUTPUT_PATH]).resolveSymbolicLinksSync(),
      templatesPath: new File(results[Config.TEMPLATES_PATH]).resolveSymbolicLinksSync(),
      isDbUsed: true,
      dbLogin: results[Config.DB_LOGIN],
      dbPassword: results[Config.DB_PASSWORD],
      dbHost: results[Config.DB_HOST],
      dbPort: results[Config.DB_PORT],
      dbName: results[Config.DB_NAME]);
  logging.initialize();

  await runHtmlGenerator(config);

  config.deallocDbPool();
  exit(0);
}

Future runHtmlGenerator(Config config) async {
  var packageLoader = new DbPackageLoader(config);
  Iterable<Package> allPackages = await packageLoader.getAllPackages();

  var parsedData = await (new DbParsedDataLoader(config).load(allPackages));

  new HtmlPackageGenerator(config, allPackages, parsedData).generate();
  var generatedPackages = config.generatedPackageInfos.map((packageInfos) {
    return packageInfos.fold([], (memo, packageInfo) {
      var package = allPackages.firstWhere((p) => p.packageInfo == packageInfo, orElse: () => null);
      if (package != null) {
        memo.add(package);
      }
      return memo;
    });
  });
  print(generatedPackages);
  new HtmlIndexGenerator(config, generatedPackages)..generate()..generatePackagePages();
}
