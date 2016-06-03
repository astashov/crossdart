library crossdart.parser;

import 'package:crossdart/src/parser/ast_visitor.dart';
import 'package:crossdart/src/parser/compilation_unit_resolver.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:logging/logging.dart' as logging;

var _logger = new logging.Logger("parser");

class Parser {
  final Environment environment;

  Parser(this.environment);

  ParsedData parseProject() {
    var absolutePaths = environment.packages.map((p) => p.absolutePaths).expand((i) => i);
    _logger.info("Building computation unit");
    var compilationUnitResolver = new CompilationUnitResolver.build(environment.config, absolutePaths);
    _logger.info("Done with building computation unit");
    var parsedData = new ParsedData();
    for (var absolutePath in environment.package.absolutePaths) {
      _parseAbsolutePath(compilationUnitResolver, absolutePath, parsedData);
    }
    return parsedData;
  }

  void _parseAbsolutePath(CompilationUnitResolver compilationUnitResolver, String absolutePath, ParsedData parsedData) {
    _logger.info("Parsing file $absolutePath");
    var resolvedUnit = compilationUnitResolver.compilationUnit(absolutePath);
    if (resolvedUnit != null) {
      var visitor = new ASTVisitor(environment, absolutePath, parsedData);
      resolvedUnit.accept(visitor);
    } else {
      _logger.warning("Wasn't be able to resolve unit, giving up...");
    }
  }
}


