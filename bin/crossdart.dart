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

Logger _logger = new Logger("parse");

Future main(args) async {
  var crossdartArgs = new CrossdartArgs(args);
  if (!crossdartArgs.runChecks()) {
    return;
  }
  var results = crossdartArgs.results;

  var config = new Config.buildFromFiles(
      dirroot: results[Config.DIR_ROOT],
      projectPath: new File(results[Config.PROJECT_PATH]).resolveSymbolicLinksSync(),
      outputPath: new File(results[Config.OUTPUT_PATH]).resolveSymbolicLinksSync(),
      isDbUsed: false);
  logging.initialize();

  var environment = await buildEnvironment(config);
  var parsedData = await new Parser(environment).parseProject();
  new JsonGenerator(environment, parsedData).generate();

  exit(0);
}
