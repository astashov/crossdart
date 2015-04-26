#!/usr/bin/env dart

library generate_packages_html;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/store/db_parsed_data_loader.dart';
import 'package:crossdart/src/store/db_package_loader.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/src/db_pool.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:crossdart/src/html_package_generator.dart';
import 'package:crossdart/src/html_index_generator.dart';

Logger _logger = new Logger("generate_html");

Future main(args) async {
  var config = new Config(
      sdkPath: args[0],
      installPath: args[1],
      outputPath: args[2],
      templatesPath: args[3],
      packagesPath: p.join(args[1], "packages"),
      isDbUsed: true);
  logging.initialize();

  await runHtmlGenerator(config);

  dbPool.close();
  exit(0);
}

Future runHtmlGenerator(Config config) async {
  var packageLoader = new DbPackageLoader(config);
  var allPackages = await packageLoader.getAllPackages();

  var parsedData = await (new DbParsedDataLoader(config).load(allPackages));

  new HtmlPackageGenerator(config, allPackages, parsedData).generate();
  new HtmlIndexGenerator(config)..generate()..generatePackagePages();
}
