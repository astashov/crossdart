library crossdart.parser.compilation_unit_resolver;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';

import 'package:crossdart/src/config.dart';
import 'package:logging/logging.dart' as logging;

var _logger = new logging.Logger("parser.compilation_unit_resolver");

class CompilationUnitResolver {
  final AnalysisContext _analysisContext;
  final Map<String, LibraryElement> _librariesByParts;
  final Iterable<String> absolutePaths;

  CompilationUnitResolver._(this._analysisContext, this._librariesByParts, this.absolutePaths);

  factory CompilationUnitResolver.build(Config config, Iterable<String> absolutePaths) {
    var resolvers = [
        new DartUriResolver(config.sdk),
        new PackageUriResolver([new JavaFile(config.packagesPath)]),
        new FileUriResolver()];

    var analysisContext = AnalysisEngine.instance.createAnalysisContext();
    analysisContext.sourceFactory = new SourceFactory(resolvers);

    var changeSet = new ChangeSet();
    absolutePaths.forEach((String f) {
      Source s = new FileBasedSource.con1(new JavaFile(f));
      changeSet.addedSource(s);
    });
    analysisContext.applyChanges(changeSet);

    var librariesByParts = absolutePaths.fold({}, (Map<String, LibraryElement> memo, String f) {
      Source s = new FileBasedSource.con1(new JavaFile(f));
      var libElement = analysisContext.computeLibraryElement(s);
      if (libElement != null) {
        libElement.parts.map((p) => p.toString()).forEach((part) {
          memo[part] = libElement;
        });
      }
      return memo;
    });

    return new CompilationUnitResolver._(analysisContext, librariesByParts, absolutePaths);
  }

  CompilationUnit compilationUnit(String absolutePath) {
    Source source = new FileBasedSource.con1(new JavaFile(absolutePath));
    var library = _librariesByParts[absolutePath];
    if (library == null) {
      library = _analysisContext.computeLibraryElement(source);
      if (library == null || library.name == "") {
        var pathsWithLibraries = _analysisContext.getLibrariesContaining(source);
        if (pathsWithLibraries.isNotEmpty) {
          library = _analysisContext.computeLibraryElement(pathsWithLibraries.first);
        }
      }
    }
    _logger.info("Library: $library");
    return _analysisContext.resolveCompilationUnit(source, library);
  }
}