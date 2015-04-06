#!/usr/bin/env dart

library parse_and_generate;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'parse.dart';
import 'generate_html.dart';
import 'package:crossdart/src/db_pool.dart';

Future main(args) async {
  var config = new Config.fromArgs(args);
  logging.initialize();
  await runParser(config);
  await runHtmlGenerator(config);
  deallocDbPool();
  exit(0);
}