library crossdart.parser.compilation_unit_resolver;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/source/package_map_resolver.dart';
import 'package:path/path.dart' as p;

import 'package:crossdart/src/config.dart';
import 'package:logging/logging.dart' as logging;
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/file_system/file_system.dart' as fs;
import 'package:analyzer/source/package_map_provider.dart';
import 'package:analyzer/source/pub_package_map_provider.dart';

var _logger = new logging.Logger("parser.compilation_unit_resolver");

class CompilationUnitResolver {
  final AnalysisContext _analysisContext;
  final Map<String, LibraryElement> _librariesByParts;
  final Iterable<String> absolutePaths;

  CompilationUnitResolver._(this._analysisContext, this._librariesByParts, this.absolutePaths);

  factory CompilationUnitResolver.build(Config config, Iterable<String> absolutePaths) {
    fs.Resource cwd = PhysicalResourceProvider.INSTANCE.getResource(config.input);
    PubPackageMapProvider pubPackageMapProvider = new PubPackageMapProvider(PhysicalResourceProvider.INSTANCE, config.sdk);
    PackageMapInfo packageMapInfo = pubPackageMapProvider.computePackageMap(cwd);
    Map<String, List<fs.Folder>> packageMap = packageMapInfo.packageMap;

    var resolvers = [
        new DartUriResolver(config.sdk),
        new PackageMapUriResolver(PhysicalResourceProvider.INSTANCE, packageMap),
        new FileUriResolver()];

    var analysisContext = AnalysisEngine.instance.createAnalysisContext();
    analysisContext.sourceFactory = new SourceFactory(resolvers);

    AnalysisOptionsImpl contextOptions = new AnalysisOptionsImpl();
    contextOptions.cacheSize = 512;
    analysisContext.analysisOptions = contextOptions;

    var changeSet = new ChangeSet();
    absolutePaths.forEach((String f) {
      Source s = new FileBasedSource(new JavaFile(f));
      changeSet.addedSource(s);
    });
    analysisContext.applyChanges(changeSet);

    var librariesByParts = absolutePaths.fold({}, (Map<String, LibraryElement> memo, String f) {
      Source s = new FileBasedSource(new JavaFile(f));
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
    Source source = new FileBasedSource(new JavaFile(absolutePath));
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