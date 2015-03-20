library crossdart.html_generator;

import 'dart:io';
import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/cache.dart';
import 'package:path/path.dart' as path;

class HtmlGenerator {
  Package _package;
  ParsedData _parsedData;

  HtmlGenerator(this._package, this._parsedData);

  void generate() {
    var handledFiles = new Set();
    this._parsedData.files.forEach((String file, Set<Entity> entities) {
      print(file);
      var references = entities.where((e) => e is Reference);
      if (references.isNotEmpty) {
        if (!(new File(references.first.location.writePath).existsSync())) {
          var content = buildContent(file, references);
          writeFile(references.first.location, content);
        }
      }
    });
  }

  String buildContent(String file, Set<Reference> references) {
    var content = "<pre>";
    var fileContent = cache.fileContents(file);
    var referencesList = references.toList()..sort((a, b) => Comparable.compare(a.offset, b.offset));
    var lastOffset = 0;
    print(file);
    referencesList.forEach((reference) {
      var declaration = _parsedData.references[reference];
      content += fileContent.substring(lastOffset, reference.offset);
      content += "<a href='${declaration.location.htmlPath}#line-${declaration.lineNumber}'>";
      content += fileContent.substring(reference.offset, reference.end);
      content += "</a>";
      lastOffset = reference.end;
    });
    content += fileContent.substring(lastOffset);
    content += "</pre>";

    var i = -1;
    content = content.split(new RegExp("(\r\n|\n|\r)", multiLine: true)).map((line) {
      i += 1;
      return "<a id='line-${i}'></a>" + line;
    }).join("\n");

    return content;
  }

  void writeFile(Location location, String content) {
    var directory = new Directory(path.dirname(location.writePath));
    directory.createSync(recursive: true);
    print("Writing to ${location.writePath}");
    new File(location.writePath).writeAsStringSync(content);
  }
}

//    var location = references[0].location;
//    var d = path.join(config.htmlPath, location.package.name, location.path);
//    var directory = new Directory(d);
//    directory.createSync(recursive: true);
//    var outputFile = new File(path.join(path.current, "out", location.package, "${location.path}.html"));
//    outputFile.writeAsStringSync(content);

//  while (parsedData.files.keys.toSet().difference(parsedData.handledFiles).isNotEmpty) {
//    var unhandledFiles = parsedData.files.keys.toSet().difference(parsedData.handledFiles);
//    unhandledFiles.forEach((file) {
//      parsedData.handledFiles.add(file);
//      parseFile(file);
//    });
//  }
//
//  var file = "/Users/anton/projects/mixbook/crossdart/ex.dart";
//  var references = parsedData.files[file];
//    var content = "<pre>";
//    var fileContent = parsedData.fileContents(file);
//    references = references.where((r) => r is Reference).toList()..sort((a, b) => Comparable.compare(a.offset, b.offset));
//    var lastOffset = 0;
//    references.forEach((reference) {
//      var declaration = parsedData.references[reference];
//      print(declaration);
//      content += fileContent.substring(lastOffset, reference.offset);
//      content += "<a href='/${declaration.location.path}#line-${declaration.lineNumber}'>";
//      content += fileContent.substring(reference.offset, reference.end);
//      content += "</a>";
//      lastOffset = reference.end;
//    });
//    content += fileContent.substring(lastOffset);
//
//    var location = references[0].location;
//    var d = path.join(path.current, "out", location.package, path.dirname(location.path).replaceAll(new RegExp(r"^\.$"), ""));
//    var directory = new Directory(d);
//    directory.createSync(recursive: true);
//    var outputFile = new File(path.join(path.current, "out", location.package, "${location.path}.html"));
//    content += "</pre>";
//    outputFile.writeAsStringSync(content);
//  }
//}