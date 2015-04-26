#!/usr/bin/env dart

library parse_and_generate_for_project;

import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/generator/json_generator.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/src/parser.dart';
import 'package:logging/logging.dart';

Logger _logger = new Logger("parse");

Future main(args) async {
  var config = new Config(
      sdkPath: new File(args[0]).resolveSymbolicLinksSync(),
      packagesPath: new File(p.join(args[1], 'packages')).resolveSymbolicLinksSync(),
      outputPath: new File(args[1]).resolveSymbolicLinksSync(),
      projectPath: new File(args[1]).resolveSymbolicLinksSync(),
      isDbUsed: false);
  logging.initialize();

  var environment = await buildEnvironment(config);
  var parsedData = await new Parser(environment).parseProject();
  new JsonGenerator(environment, parsedData).generate();

  exit(0);
}