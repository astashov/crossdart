library crossdart.parser;

import 'dart:async';
import 'package:crossdart/src/isolate_events.dart';
import 'package:crossdart/src/parser/ast_visitor.dart';
import 'package:crossdart/src/parser/compilation_unit_resolver.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/store/db_parsed_data_loader.dart';
import 'package:logging/logging.dart' as logging;

var _logger = new logging.Logger("parser");

class Parser {
  final Environment environment;

  Parser(this.environment);

  Future<ParsedData> parsePackages() {
    return new DbParsedDataLoader(environment.config).load(environment.packages).then((parsedData) {
      var absolutePaths = environment.packages.map((p) => p.absolutePaths).expand((i) => i);
      var compilationUnit = new CompilationUnitResolver.build(environment.config, absolutePaths);
      _sendIsolateEvent(IsolateEvent.START_PARSING);
      _parseAbsolutePathsOf(compilationUnit, absolutePaths, parsedData);
      //_parseAbsolutePath(compilationUnit, "/Users/anton/.pub-cache/hosted/pub.dartlang.org/dnd-0.3.0/lib/src/draggable.dart", parsedData);
      _sendIsolateEvent(IsolateEvent.FINISH_PARSING);
      return parsedData;
    });
  }

  ParsedData parseProject() {
    var absolutePaths = environment.packages.map((p) => p.absolutePaths).expand((i) => i);
    var compilationUnitResolver = new CompilationUnitResolver.build(environment.config, absolutePaths);
    var parsedData = new ParsedData();
    for (var absolutePath in environment.package.absolutePaths) {
      _parseAbsolutePath(compilationUnitResolver, absolutePath, parsedData);
    }
    return parsedData;
  }

  ParsedData _parseAbsolutePathsOf(CompilationUnitResolver compilationUnitResolver, Iterable<String> absolutePaths, ParsedData parsedData) {
    var handledFiles = parsedData.files.keys.toSet();

    for (var absolutePath in absolutePaths) {
      if (!handledFiles.contains(absolutePath)) {
        _parseAbsolutePath(compilationUnitResolver, absolutePath, parsedData);
        while (parsedData.files.keys.toSet().difference(handledFiles).isNotEmpty) {
          var unhandledFiles = parsedData.files.keys.toSet().difference(handledFiles);
          for (var unhandledFile in unhandledFiles) {
            handledFiles.add(unhandledFile);
            _parseAbsolutePath(compilationUnitResolver, unhandledFile, parsedData);
          }
        }
      }
    }

    return parsedData;
  }

  void _parseAbsolutePath(CompilationUnitResolver compilationUnitResolver, String absolutePath, ParsedData parsedData) {
    _logger.info("Parsing file $absolutePath");
    _sendIsolateEvent(IsolateEvent.START_FILE_PARSING);
    var resolvedUnit = compilationUnitResolver.compilationUnit(absolutePath);
    if (resolvedUnit != null) {
      var visitor = new ASTVisitor(environment, absolutePath, parsedData);
      resolvedUnit.accept(visitor);
      _sendIsolateEvent(IsolateEvent.FINISH_FILE_PARSING);
    } else {
      _logger.warning("Wasn't be able to resolve unit, giving up...");
      _sendIsolateEvent(IsolateEvent.FINISH_FILE_PARSING);
    }
  }

  void _sendIsolateEvent(IsolateEvent event) {
    if (environment.sender != null) {
      environment.sender.send(event);
    }
  }

}


