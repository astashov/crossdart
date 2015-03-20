#!/usr/bin/env dart

import 'dart:io';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/crossdart.dart';

void main(args) {
  config = new Config.fromArgs(args);
  logging.initialize();
  var packageName = args[3];
  var package = new CustomPackage.fromName(packageName);
  //install(packageName);

  var parsedData = parse(package);
  generateHtml(package, parsedData);

  //customPackages.forEach((package) {
    //package.children.where((f) => f is File).forEach((file) {
      //
    //});
  //});

//  var packageName = args[3];
//  install(packageName);

//  var package = new Package.fromName(packageName);
//  package.children.where((f) => f is File).forEach((file) {
//    parse(file);
//  });


//  config = new Config.fromArgs(args);
//  var p = new Package.fromName("frappe");
//  print(p.filePaths);
}