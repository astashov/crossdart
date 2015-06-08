#!/usr/bin/env dart

library generate_packages_html;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/args.dart';
import 'package:crossdart/src/html/url.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/store/db_parsed_data_loader.dart';
import 'package:crossdart/src/store/db_package_loader.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:crossdart/src/html_package_generator.dart';
import 'package:crossdart/src/html_index_generator.dart';
import 'package:crossdart/src/util/iterable.dart';

Logger _logger = new Logger("generate_html");

Future main(args) async {
  var generatePackagesHtml = new GeneratePackagesHtmlArgs(args);
  if (!generatePackagesHtml.runChecks()) {
    return;
  }
  var results = generatePackagesHtml.results;

  new Directory(results[Config.OUTPUT_PATH]).createSync(recursive: true);

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

  deallocDbPool();
  exit(0);
}

Future runHtmlGenerator(Config config) async {
  new Directory(p.join(config.outputPath, PATH_PREFIX)).createSync(recursive: true);

  var packageLoader = new DbPackageLoader(config);
  Iterable<PackageInfo> _allPackageInfos = (await packageLoader.getAllPackageInfos());
  _logger.info("Total number of packages - ${_allPackageInfos.length}");
  var generatedPackageInfosSet = config.generatedPackageInfos.expand((i) => i).toSet();

  var erroredPackageInfos = await dbPool(config).query("""
    SELECT package_name AS name, package_version AS version FROM errors
  """);
  erroredPackageInfos = (await erroredPackageInfos.toList()).map((p) {
    return new PackageInfo(p.name, new Version(p.version));
  });

  Set<PackageInfo> allPackageInfos = _allPackageInfos.where((pi) {
    var generatedPackageInfo = pi.update(version: new Version(pi.version.toPath()));
    return !generatedPackageInfosSet.contains(generatedPackageInfo) && !erroredPackageInfos.contains(generatedPackageInfo);
  });

  _logger.info("Updated number of packages - ${allPackageInfos.length}");

  await buildSdkFromFileSystem(config, new PackageInfo.buildSdk(config));
  List<Package> _packages = [];

  var index = 0;
  for (var packageInfos in inGroupsOf(allPackageInfos, 100)) {
    _logger.info("Loading packages with dependencies from db - $index");
    Set<PackageInfo> thisPackageInfos = new Set();
    for (var packageInfo in packageInfos) {
      thisPackageInfos.addAll(await packageLoader.getPackageInfoDependencies(packageInfo));
    }

    _logger.info("Loading packages");
    var packages = new Set();
    for (var pi in thisPackageInfos) {
      packages.add(await buildFromFileSystem(config, pi));
    }

    _logger.info("Loading parsed data");
    var parsedData = await (new DbParsedDataLoader(config).load(packages));

    _logger.info("Generating HTML pages");
    new HtmlPackageGenerator(config, packages, parsedData).generate();

    _packages.addAll(packages);
    index += 1;
  }

  var generatedPackages = [];
  for (var generatedPackageInfos in config.generatedPackageInfos) {
    var pis = [];
    for (var generatedPackageInfo in generatedPackageInfos) {
      print(generatedPackageInfo);
      pis.add(await buildFromFileSystem(config, generatedPackageInfo));
    }
    generatedPackages.add(pis);
  }
  new HtmlIndexGenerator(config, generatedPackages)..generate()..generatePackagePages();
}
