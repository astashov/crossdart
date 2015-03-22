#!/usr/bin/env dart

import 'dart:io';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/crossdart.dart';
import 'package:crossdart/src/service.dart';

void main(args) async {
  config = new Config.fromArgs(args);
  logging.initialize();
  var packageName = args[3];

//  var packages = await getAvailablePackages();
//  packages.forEach((packageName) {
    install(packageName);
    var package = new CustomPackage.fromName(packageName);
    var parsedData = parse(package);
    generateHtml(package, parsedData);
//  });
}