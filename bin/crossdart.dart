#!/usr/bin/env dart

library parse_and_generate_for_project;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/args.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/generator/json_generator.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/src/parser.dart';
import 'package:logging/logging.dart';
import 'package:crossdart/src/html_package_generator.dart';

Logger _logger = new Logger("parse");

Future main(args) async {
  var crossdartArgs = new CrossdartArgs(args);
  if (!crossdartArgs.runChecks()) {
    return;
  }
  var results = crossdartArgs.results;

  var config = await Config.build(
      dartSdk: results[Config.DART_SDK],
      input: results[Config.INPUT],
      output: results[Config.OUTPUT],
      hostedUrl: results[Config.HOSTED_URL],
      urlPathPrefix: results[Config.URL_PREFIX_PATH],
      outputFormat: results[Config.OUTPUT_FORMAT] == "json" ? OutputFormat.JSON : OutputFormat.HTML);
  logging.initialize();

  var environment = await buildEnvironment(config);
  var parsedData = await new Parser(environment).parseProject();
  if (config.outputFormat == OutputFormat.JSON) {
    new JsonGenerator(environment, parsedData).generate();
  } else {
    await new HtmlPackageGenerator(config, [environment.package], parsedData).generateProject();
  }

  exit(0);
}
