library crossdart.parser;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/isolate_events.dart';
import 'package:crossdart/src/parser/ast_visitor.dart';
import 'package:crossdart/src/parser/compilation_unit_resolver.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/store/db_parsed_data_loader.dart';
import 'package:path/path.dart' as p;
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
      parsedData = parsedData.merge(_parseAbsolutePathsOf(compilationUnit, absolutePaths));
      _sendIsolateEvent(IsolateEvent.FINISH_PARSING);
      return parsedData;
    });
  }

  Future<ParsedData> parseProject() {
    var absolutePaths = environment.packages.map((p) => p.absolutePaths).expand((i) => i);
    var compilationUnitResolver = new CompilationUnitResolver.build(environment.config, absolutePaths);
    var parsedData = new ParsedData();
    for (var absolutePath in environment.package.absolutePaths) {
      parsedData = parsedData.merge(_parseAbsolutePath(compilationUnitResolver, absolutePath));
    }
    return parsedData;
  }

  ParsedData _parseAbsolutePathsOf(CompilationUnitResolver compilationUnitResolver, Iterable<String> absolutePaths) {
    var parsedData = new ParsedData();
    var handledFiles = parsedData.files.keys.toSet();

    for (var absolutePath in absolutePaths) {
      if (!handledFiles.contains(absolutePath)) {
        parsedData = parsedData.merge(_parseAbsolutePath(compilationUnitResolver, absolutePath));
        while (parsedData.files.keys.toSet().difference(handledFiles).isNotEmpty) {
          var unhandledFiles = parsedData.files.keys.toSet().difference(handledFiles);
          for (var unhandledFile in unhandledFiles) {
            handledFiles.add(unhandledFile);
            parsedData = parsedData.merge(_parseAbsolutePath(compilationUnitResolver, unhandledFile));
          }
        }
      }
    }

    return parsedData;
  }

  ParsedData _parseAbsolutePath(CompilationUnitResolver compilationUnitResolver, String absolutePath) {
    _logger.info("Parsing file $absolutePath");
    _sendIsolateEvent(IsolateEvent.START_FILE_PARSING);
    var resolvedUnit = compilationUnitResolver.compilationUnit(absolutePath);
    if (resolvedUnit != null) {
      var visitor = new ASTVisitor(environment, absolutePath);
      resolvedUnit.accept(visitor);
      _sendIsolateEvent(IsolateEvent.FINISH_FILE_PARSING);
      return visitor.parsedData;
    } else {
      _logger.warning("Wasn't be able to resolve unit, giving up...");
      _sendIsolateEvent(IsolateEvent.FINISH_FILE_PARSING);
      return new ParsedData();
    }
  }

  void _sendIsolateEvent(IsolateEvent event) {
    if (environment.sender != null) {
      environment.sender.send(event);
    }
  }

}


