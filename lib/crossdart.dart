library crossdart;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/parser.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/store.dart';

import 'package:crossdart/src/installer/installer.dart';
import 'package:crossdart/src/html_package_generator.dart';
import 'package:crossdart/src/html_index_generator.dart';

void install(Config config, PackageInfo packageInfo) {
  new Installer(config, packageInfo).install();
}

Future<ParsedData> parse(Environment environment) async {
  ParsedData parsedData = await load(environment);

  var handledFiles = parsedData.files.keys.toSet();

  for (var file in environment.package.files) {
    var path = file.path;
    if (!_isFileAlreadyGenerated(environment, path) && !handledFiles.contains(path)) {
      parsedData = parsedData.merge(await parseFile(environment, path));
      while (parsedData.files.keys.toSet().difference(handledFiles).isNotEmpty) {
        var unhandledFiles = parsedData.files.keys.toSet().difference(handledFiles);
        for (var unhandledFile in unhandledFiles) {
          handledFiles.add(unhandledFile);
          if (!_isFileAlreadyGenerated(environment, unhandledFile)) {
            parsedData = parsedData.merge(await parseFile(environment, unhandledFile));
          }
        }
      }
    }
  }

  return parsedData;
}

void generatePackageHtml(Environment environment, ParsedData parsedData) {
  new HtmlPackageGenerator(environment, parsedData).generate();
}

void generateIndexHtml(Config config) {
  new HtmlIndexGenerator(config)..generate()..generatePackagePages();
}

bool _isFileAlreadyGenerated(Environment environment, String filePath) {
  var package = Package.fromFilePath(environment, filePath);
  var location = new Location(environment.config, filePath, package);
  return new File(location.writePath).existsSync();
}