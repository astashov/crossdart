library crossdart.html_package_generator;

import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/cache.dart';
import 'package:crossdart/src/google_analytics.dart' as ga;
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

var _logger = new Logger("html_package_generator");

class HtmlPackageGenerator {
  ParsedData _parsedData;
  Iterable<Package> _packages;
  HtmlEscape sanitizer = const HtmlEscape();
  Config _config;

  HtmlPackageGenerator(this._config, this._packages, this._parsedData);

  void generate() {
    var packagesByFiles = _packages.fold({}, (Map<String, Package> memo, Package package) {
      package.absolutePaths.forEach((file) {
        memo[file] = package;
      });
      return memo;
    });

    this._parsedData.files.forEach((String absolutePath, Set<Entity> entities) {
      Package package = packagesByFiles[absolutePath];
      var location = new Location(package, package.relativePath(absolutePath));
      entities = entities.where((e) => e.offset != null && e.end != null).toSet();
      if (!(new File(location.writePath(_config)).existsSync())) {
        var directory = new Directory(path.dirname(location.writePath(_config)));
        directory.createSync(recursive: true);
        var file = new File(location.writePath(_config)).openSync(mode: FileMode.WRITE);
        _writeContent(absolutePath, entities, file, package);
        file.closeSync();
      }
    });
  }

  String _addEntityStart(Entity entity) {
    if (entity is Reference) {
      var declaration = _parsedData.references[entity];
      var content = "<a href='${declaration.location.htmlPath}";
      if (declaration.lineNumber != null) {
        content += "#line-${declaration.lineNumber}";
      }
      content += "' class='entity__reference'>";
      return content;
    } else if (entity is Declaration) {
      return "<span id='declaration-${entity.id}' class='entity__declaration'>";
    } else if (entity is Token) {
      return "<span class='${entity.name}'>";
    } else {
      return "<span>";
    }
  }

  String _addEntityEnd(Entity entity) {
    if (entity is Reference) {
      return "</a>";
    } else {
      return "</span>";
    }
  }

  String _headerContent(String absolutePath, Package package) {
    var location = new Location(package, package.relativePath(absolutePath));
    return """
      <!doctype html>
      <html lang="en-us">
        <head>
          <title>'${package.name}' - ${location.path} | CrossDart - cross-referenced Dart's pub packages</title>
          <link rel="stylesheet" href="/style.css" type="text/css">
        </head>
        <body class='source-code'>
          <nav class='nav'>
            <a href='/${package.name}#${package.version}' class='nav-back'>${package.name} (${package.version})</a>
            <a class="link-to-pub" href="${package.pubUrl}">Link to Pub</a>
          </nav>
    """;
  }

  String _footerContent() {
    return """
        ${ga.script}
      </body>
      </html>
    """;
  }

  void _writeContent(String absolutePath, Set<Entity> entities, RandomAccessFile file, Package package) {
    _logger.info("Building content of ${absolutePath}");
    file.writeStringSync(_headerContent(absolutePath, package));
    file.writeStringSync("<pre class='code'>");
    String fileContent = cache.fileContents(absolutePath);
    List<Entity> entitiesList = entities.toList()..sort((a, b) => Comparable.compare(a.offset, b.offset));

    var lastOffset = 0;
    var currentLine = 0;
    file.writeStringSync("<a id='line-${currentLine}' class='line'>${currentLine}</a>");
    currentLine += 1;
    Map<int, List<Entity>> stack = {};
    String newlineChar = cache.getNewlineChar(fileContent);

    Entity entity = entitiesList.isNotEmpty ? entitiesList.removeAt(0) : null;
    int nextNewlinePos = fileContent.indexOf(newlineChar, lastOffset);

    while(entity != null || stack.isNotEmpty || nextNewlinePos != null) {
      int entityStartPos = entity != null ? entity.offset : null;
      nextNewlinePos = fileContent.indexOf(newlineChar, lastOffset);
      nextNewlinePos = nextNewlinePos == -1 ? null : nextNewlinePos;
      int entityEndPos = stack.isNotEmpty ? stack.keys.reduce(math.min) : null;

      var positions = [entityStartPos, nextNewlinePos, entityEndPos].where((i) => i != null);
      if (positions.isNotEmpty) {
        int nextStop = positions.reduce(math.min);
        var string = fileContent.substring(lastOffset, nextStop);
        file.writeStringSync(sanitizer.convert(string));
        if (entityEndPos == nextStop || entityStartPos == nextStop) {
          if (entityEndPos == nextStop) {
            Entity referenceFromStack = stack[entityEndPos].removeLast();
            if (stack[entityEndPos].isEmpty) {
              stack.remove(entityEndPos);
            }
            file.writeStringSync(_addEntityEnd(referenceFromStack));
          }
          if (entityStartPos == nextStop) {
            if (stack[entity.end] == null) {
              stack[entity.end] = [];
            }
            stack[entity.end].add(entity);
            file.writeStringSync(_addEntityStart(entity));
            entity = entitiesList.isNotEmpty ? entitiesList.removeAt(0) : null;
          }
          lastOffset = nextStop;
        } else {
          if (nextNewlinePos == nextStop) {
            file.writeStringSync("\n");
            file.writeStringSync("<a id='line-${currentLine}' class='line'>${currentLine}</a>");
            currentLine += 1;
            lastOffset = nextStop + newlineChar.length;
          } else {
            lastOffset = nextStop;
          }
        }
      } else {
        file.writeStringSync(sanitizer.convert(fileContent.substring(lastOffset)));
      }
    }

    file.writeStringSync("</pre>");
    file.writeStringSync(_footerContent());
  }
}