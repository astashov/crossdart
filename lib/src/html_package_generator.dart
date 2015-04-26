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

var _logger = new Logger("generator");

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
      var tokens = entities.where((e) => e is Token).toSet();
      if (!(new File(location.writePath(_config)).existsSync())) {
        var directory = new Directory(path.dirname(location.writePath(_config)));
        directory.createSync(recursive: true);
        var file = new File(location.writePath(_config)).openSync(mode: FileMode.WRITE);
        _writeContent(absolutePath, tokens, file, package);
        file.closeSync();
      }
    });
  }

  String _addTokenStart(Token token) {
    if (token is Reference) {
      var declaration = _parsedData.references[token];
      var content = "<a href='${declaration.location.htmlPath}";
      if (declaration.lineNumber != null) {
        content += "#line-${declaration.lineNumber}";
      }
      content += "' class='reference'>";
      return content;
    } else {
      return "<span class='${token.name}'>";
    }
  }

  String _addTokenEnd(Token token) {
    if (token is Reference) {
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

  void _writeContent(String absolutePath, Set<Token> tokens, RandomAccessFile file, Package package) {
    _logger.info("Building content of ${absolutePath}");
    file.writeStringSync(_headerContent(absolutePath, package));
    file.writeStringSync("<pre class='code'>");
    String fileContent = cache.fileContents(absolutePath);
    List<Token> tokensList = tokens.toList()..sort((a, b) => Comparable.compare(a.offset, b.offset));



    var lastOffset = 0;
    var currentLine = 0;
    file.writeStringSync("<a id='line-${currentLine}' class='line'>${currentLine}</a>");
    currentLine += 1;
    List<Token> stack = [];
    var newlineChar = cache.getNewlineChar(fileContent);

    Token token = tokensList.isNotEmpty ? tokensList.removeAt(0) : null;
    int nextNewlinePos = fileContent.indexOf(newlineChar, lastOffset);

    while(token != null || stack.isNotEmpty || nextNewlinePos != null) {
      var tokenStartPos = token != null ? token.offset : null;
      nextNewlinePos = fileContent.indexOf(newlineChar, lastOffset);
      nextNewlinePos = nextNewlinePos == -1 ? null : nextNewlinePos;
      var tokenEndPos = stack.isNotEmpty ? stack.last.end : null;

      var positions = [tokenStartPos, nextNewlinePos, tokenEndPos].where((i) => i != null);
      if (positions.isNotEmpty) {
        var nextStop = positions.reduce(math.min);
        file.writeStringSync(sanitizer.convert(fileContent.substring(lastOffset, nextStop)));
        if (tokenEndPos == nextStop || tokenStartPos == nextStop) {
          if (tokenEndPos == nextStop) {
            Token referenceFromStack = stack.removeLast();
            file.writeStringSync(_addTokenEnd(referenceFromStack));
          }
          if (tokenStartPos == nextStop) {
            stack.add(token);
            file.writeStringSync(_addTokenStart(token));
            token = tokensList.isNotEmpty ? tokensList.removeAt(0) : null;
          }
          lastOffset = nextStop;
        } else {
          if (nextNewlinePos == nextStop) {
            file.writeStringSync(newlineChar);
            file.writeStringSync("<a id='line-${currentLine}' class='line'>${currentLine}</a>");
            currentLine += 1;
            lastOffset = nextStop + 1;
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