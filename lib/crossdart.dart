library crossdart;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/parser.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/store/db_parsed_data_loader.dart';
import 'package:crossdart/src/isolate_events.dart';

import 'package:crossdart/src/installer/installer.dart';
import 'package:crossdart/src/html_package_generator.dart';
import 'package:crossdart/src/html_index_generator.dart';

void install(Config config, PackageInfo packageInfo) {
  new Installer(config, packageInfo).install();
}

Future<ParsedData> parse(Environment environment) {
  return new DbParsedDataLoader(environment.config).load(environment.packages).then((parsedData) {
    environment.sender.send(IsolateEvent.START_PARSING);
    var handledFiles = parsedData.files.keys.toSet();

    for (var absolutePath in environment.package.absolutePaths) {
      if (!_isFileAlreadyGenerated(environment, absolutePath) && !handledFiles.contains(absolutePath)) {
        parsedData = parsedData.merge(parseFile(environment, absolutePath));
        while (parsedData.files.keys.toSet().difference(handledFiles).isNotEmpty) {
          var unhandledFiles = parsedData.files.keys.toSet().difference(handledFiles);
          for (var unhandledFile in unhandledFiles) {
            handledFiles.add(unhandledFile);
            if (!_isFileAlreadyGenerated(environment, unhandledFile)) {
              parsedData = parsedData.merge(parseFile(environment, unhandledFile));
            }
          }
        }
      }
    }
    environment.sender.send(IsolateEvent.FINISH_PARSING);

    return parsedData;
  });
}

void generatePackageHtml(Config config, Iterable<Package> packages, ParsedData parsedData) {
  new HtmlPackageGenerator(config, packages, parsedData).generate();
}

void generateIndexHtml(Config config) {
  new HtmlIndexGenerator(config)..generate()..generatePackagePages();
}

bool _isFileAlreadyGenerated(Environment environment, String absolutePath) {
  var package = Package.fromAbsolutePath(environment, absolutePath);
  var location = new Location(package, package.relativePath(absolutePath));
  return new File(location.writePath(environment.config)).existsSync();
}