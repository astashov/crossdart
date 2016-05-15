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
import 'package:crossdart/src/installer/installer.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:crossdart/src/html_package_generator.dart';
import 'package:crossdart/src/html_index_generator.dart';
import 'package:crossdart/src/util/iterable.dart';
import 'package:crossdart/src/pub_cache_package_loader.dart';
import 'package:crossdart/src/generator/generator_404.dart';

Logger _logger = new Logger("generate_html");

Future main(args) async {
  var generatePackagesHtml = new GeneratePackagesHtmlArgs(args);
  if (!generatePackagesHtml.runChecks()) {
    return;
  }
  var results = generatePackagesHtml.results;

  var config = new Config.buildFromFiles(dirroot: results[Config.DIR_ROOT], isDbUsed: true);
  new Directory(config.outputPath).createSync(recursive: true);
  logging.initialize();

  await runHtmlGenerator(config);

  deallocDbPool();
  exit(0);
}

Future runHtmlGenerator(Config config) async {
  new Directory(p.join(config.outputPath, PATH_PREFIX)).createSync(recursive: true);

  var pubCachePackageLoader = new PubCachePackageLoader(config);
  var dbPackageLoader = new DbPackageLoader(config);
  Iterable<PackageInfo> _allPackageInfos = (await pubCachePackageLoader.getAllPackageInfos()).take(10);
  _logger.info(".pub-cache number of packages - ${_allPackageInfos.length}");
  var generatedPackageInfosSet = config.generatedPackageInfos.expand((i) => i).toSet();
  _logger.info("generated number of packages - ${generatedPackageInfosSet.length}");

  final Set<PackageInfo> allPackageInfos = _allPackageInfos.where((pi) {
    var generatedPackageInfo = pi.update(version: new Version(pi.version.toPath()));
    return !generatedPackageInfosSet.contains(generatedPackageInfo);
  }).toSet();

  _logger.info("Updated number of packages - ${allPackageInfos.length}");

  await buildSdkFromFileSystem(config, new PackageInfo.buildSdk(config));
  List<Package> _packages = [];

  var index = 0;
  for (var packageInfos in inGroupsOf(allPackageInfos, 100)) {
    _logger.info("Loading packages with dependencies from db - $index");
    Set<PackageInfo> thisPackageInfos = new Set();
    for (var packageInfo in packageInfos) {
      thisPackageInfos.addAll(await dbPackageLoader.getPackageInfoDependencies(packageInfo));
    }

    _logger.info("Loading packages");
    var packages = new Set();
    for (var pi in thisPackageInfos) {
      Package package;
      try {
        package = await buildFromFileSystem(config, pi);
      } on InstallerError catch (_, __) {
        package = null;
      }
      if (package != null) {
        packages.add(package);
      }
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
      Package package;
      try {
        package = await buildFromFileSystem(config, generatedPackageInfo);
      } on InstallerError catch (_, __) {
        package = null;
      }
      if (package != null) {
        pis.add(package);
      }
    }
    generatedPackages.add(pis);
  }
  await new Generator404(config).generate();
  new HtmlIndexGenerator(config, generatedPackages)..generate()..generatePackagePages();

}
