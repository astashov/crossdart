library crossdart.html_package_generator;

import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/cache.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

var _logger = new Logger("generator");

class HtmlPackageGenerator {
  Package _package;
  ParsedData _parsedData;
  HtmlEscape sanitizer = const HtmlEscape();

  HtmlPackageGenerator(this._package, this._parsedData);

  void generate() {
    var handledFiles = new Set();
    this._parsedData.files.forEach((String fileName, Set<Entity> entities) {
      var package = Package.fromFilePath(fileName);
      var location = new Location(fileName, package);
      var tokens = entities.where((e) => e is Token).toSet();
      if (!(new File(location.writePath).existsSync())) {
        var directory = new Directory(path.dirname(location.writePath));
        directory.createSync(recursive: true);
        var file = new File(location.writePath).openSync(mode: FileMode.WRITE);
        _writeContent(fileName, tokens, file);
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
      content += "'>";
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

  void _writeContent(String fileName, Set<Token> tokens, RandomAccessFile file) {
    _logger.info("Building content of ${fileName}");
    file.writeStringSync("<pre>");
    var fileContent = cache.fileContents(fileName);
    List<Reference> tokensList = tokens.toList()..sort((a, b) => Comparable.compare(a.offset, b.offset));

    var lastOffset = 0;
    var currentLine = 0;
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
        if (tokenEndPos == nextStop) {
          Token referenceFromStack = stack.removeLast();
          file.writeStringSync(_addTokenEnd(referenceFromStack));
        }
        if (tokenStartPos == nextStop) {
          stack.add(token);
          file.writeStringSync(_addTokenStart(token));
          token = tokensList.isNotEmpty ? tokensList.removeAt(0) : null;
        }
        if (nextNewlinePos == nextStop) {
          file.writeStringSync(newlineChar);
          file.writeStringSync("<a id='line-${currentLine}'></a>");
          currentLine += 1;
          lastOffset = nextStop + 1;
        } else {
          lastOffset = nextStop;
        }
      } else {
        file.writeStringSync(sanitizer.convert(fileContent.substring(lastOffset)));
      }
    }

    file.writeStringSync("</pre>");
  }

  void _writeFile(Location location, String content) {
    _logger.info("Writing to ${location.writePath}");

    new File(location.writePath).writeAsStringSync(content);
  }
}