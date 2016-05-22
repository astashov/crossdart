#!/usr/bin/env dart

library generate_packages_html;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/args.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/store/db_package_loader.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:crossdart/src/generator/generator_404.dart';
import 'package:crossdart/src/index_generator.dart';
import 'package:crossdart/src/package_info.dart';

Logger _logger = new Logger("generate_html");

Future<Null> main(List<String> args) async {
  logging.initialize();

  var indexGenerator = new _IndexGenerator.build(args);

  while(true) {
    await indexGenerator.run();
    var duration = new Duration(minutes: 1);
    _logger.info("Waiting for ${duration.inSeconds}s...");
    await new Future.delayed(duration);
  }

  deallocDbPool();
  exit(0);
}

class _IndexGenerator {
  DateTime lastDate;
  Set<Package> successfulPackages = new Set();
  Set<PackageInfo> erroredPackages = new Set();
  final DbPackageLoader dbPackageLoader;
  final Config config;

  _IndexGenerator._(
    this.config,
    this.dbPackageLoader);

  factory _IndexGenerator.build(List<String> args) {
    var generatePackagesHtml = new GeneratePackagesHtmlArgs(args);
    if (!generatePackagesHtml.runChecks()) {
      exit(1);
    }
    var results = generatePackagesHtml.results;

    var config = new Config.buildFromFiles(dirroot: results[Config.DIR_ROOT], isDbUsed: true);
    new Directory(p.join(config.outputPath, config.gcsPrefix)).createSync(recursive: true);

    var dbPackageLoader = new DbPackageLoader(config);

    return new _IndexGenerator._(config, dbPackageLoader);
  }

  Future run() async {
    var newSuccessfulPackages = await dbPackageLoader.getAllGeneratedPackages(lastDate);
    var newErroredPackages = await dbPackageLoader.getErroredPackageInfos(lastDate);
    if (newSuccessfulPackages.isNotEmpty || newErroredPackages.isNotEmpty) {
      var indexGenerator = new IndexGenerator(config);
      successfulPackages.addAll(newSuccessfulPackages);
      erroredPackages.addAll(newErroredPackages);

      _logger.info("Number of new successful packages - ${newSuccessfulPackages.length}");
      _logger.info("Number of new errored packages - ${newErroredPackages.length}");

      await indexGenerator.generateHistory(successfulPackages, erroredPackages);
      await new Generator404(config).generate(successfulPackages, erroredPackages);

      if (newSuccessfulPackages.isNotEmpty) {
        await indexGenerator.generateHome(successfulPackages);
      }

      if (newErroredPackages.isNotEmpty) {
        await indexGenerator.generateErrors(erroredPackages);
      }
      lastDate = new DateTime.now().toUtc();
    }
  }
}

