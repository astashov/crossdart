#!/usr/bin/env dart

library parse_and_generate_for_project;

import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/generator/json_generator.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/crossdart.dart';
import 'package:crossdart/src/service.dart';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/store.dart';
import 'package:crossdart/src/parser.dart';
import 'package:logging/logging.dart';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/isolate_events.dart';

Logger _logger = new Logger("parse");

Future main(args) async {
  var config = new Config(
      sdkPath: args[0],
      packagesPath: args[2],
      outputPath: args[1],
      projectPath: args[1]);
  logging.initialize();

  var environment = await buildEnvironment(config);
  var parsedData = await new Parser(environment).parseProject();
  new JsonGenerator(environment, parsedData).generate();
  deallocDbPool();

  dbPool.close();
  exit(0);
}