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

  OutputFormat outputFormat;
  switch (results[Config.OUTPUT_FORMAT]) {
    case "json": outputFormat = OutputFormat.JSON; break;
    case "github": outputFormat = OutputFormat.GITHUB; break;
    default: outputFormat = OutputFormat.GITHUB; break;
  }

  var config = await Config.build(
      dartSdk: results[Config.DART_SDK],
      input: results[Config.INPUT],
      output: results[Config.OUTPUT] ?? results[Config.INPUT],
      hostedUrl: results[Config.HOSTED_URL] ?? "https://www.crossdart.info",
      urlPathPrefix: results[Config.URL_PATH_PREFIX] ?? "p",
      outputFormat: outputFormat);
  logging.initialize();

  var environment = await buildEnvironment(config);
  var parsedData = await new Parser(environment).parseProject();
  if (config.outputFormat == OutputFormat.HTML) {
    await new HtmlPackageGenerator(config, [environment.package], parsedData).generateProject();
  } else {
    new JsonGenerator(environment, parsedData).generate(isForGithub: config.outputFormat == OutputFormat.GITHUB);
  }

  exit(0);
}
