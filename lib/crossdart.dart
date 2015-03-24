library crossdart;

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/parser.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/location.dart';

import 'package:crossdart/src/installer/installer.dart';
import 'package:crossdart/src/html_package_generator.dart';
import 'package:crossdart/src/html_index_generator.dart';

void install(PackageInfo packageInfo) {
  assert(config != null);
  new Installer(packageInfo).install();
}

ParsedData parse(Package package) {
  var handledFiles = new Set();

  return package.files.map((f) => f.path).fold(new ParsedData(), (memo, file) {
    if (!_isFileAlreadyGenerated(file)) {
      var parsedData = parseFile(file);

      while (parsedData.files.keys.toSet().difference(handledFiles).isNotEmpty) {
        var unhandledFiles = parsedData.files.keys.toSet().difference(handledFiles);
        unhandledFiles.forEach((file) {
          handledFiles.add(file);
          if (!_isFileAlreadyGenerated(file)) {
            parsedData = parsedData.merge(parseFile(file));
          }
        });
      }

      memo = memo.merge(parsedData);
    }

    return memo;
  });

}

void generatePackageHtml(Package package, ParsedData parsedData) {
  new HtmlPackageGenerator(package, parsedData).generate();
}

void generateIndexHtml(Iterable<PackageInfo> packages) {
  new HtmlIndexGenerator(packages).generate();
}

bool _isFileAlreadyGenerated(String filePath) {
  var package = Package.fromFilePath(filePath);
  var location = new Location(filePath, package);
  return new File(location.writePath).existsSync();
}