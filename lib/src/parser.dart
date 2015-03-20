library crossdart.parser;

import 'dart:io';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';

import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/entity.dart' as e;

ParsedData parseFile(String file, Package package) {
  var resolvedUnit = _prepareCompilationUnit(file, package);
  var visitor = new _ASTVisitor(file);
  resolvedUnit.accept(visitor);
  return visitor.parsedData;
}


CompilationUnit _prepareCompilationUnit(String file, Package package) {
  print("Preparing for file $file");
  var resolvers = [new DartUriResolver(config.sdk), new FileUriResolver()];

  var packageUriResolver = new PackageUriResolver([config.packagesPath]);
  resolvers.add(packageUriResolver);

  AnalysisContext context = AnalysisEngine.instance.createAnalysisContext()
    ..sourceFactory = new SourceFactory(resolvers);

  ChangeSet changeSet = new ChangeSet();
  package.files.forEach((File f) {
    Source s = new FileBasedSource.con1(new JavaFile(f.path));
    changeSet.addedSource(s);
  });
  context.applyChanges(changeSet);

  var libraries = package.files.fold({}, (Map<LibraryElement, List<CompilationUnitElement>> memo, File f) {
    Source s = new FileBasedSource.con1(new JavaFile(f.path));
    var libElement = context.computeLibraryElement(s);
    if (libElement != null) {
      memo[libElement] = libElement.parts;
    }
    return memo;
  });

  Source source = new FileBasedSource.con1(new JavaFile(file));
  var library = context.computeLibraryElement(source);
  if (library.name == "") {
    libraries.forEach((l, parts) {
      if (parts.map((p) => p.toString()).contains(file)) {
        library = l;
      }
    });
  }

  CompilationUnit resolvedUnit =
      context.resolveCompilationUnit(source, library);

  return resolvedUnit;
}


class _ASTVisitor extends GeneralizingAstVisitor {
  String file;

  _ASTVisitor(this.file);

  ParsedData _parsedData = new ParsedData();
  ParsedData get parsedData => _parsedData;

  visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);
    Element element = node.bestElement;
    if (element != null && element.library != null && element.node is Declaration && !node.inDeclarationContext()) {
      var reference = new e.Reference(node, node.bestElement, this.file);
      var declaration = new e.Declaration(element.node, (element.node as Declaration).element);

      if (parsedData.files[reference.location.file] == null) {
        parsedData.files[reference.location.file] = new Set();
      }
      parsedData.files[reference.location.file].add(reference);

      if (parsedData.files[declaration.location.file] == null) {
        parsedData.files[declaration.location.file] = new Set();
      }
      parsedData.files[declaration.location.file].add(declaration);

      if (parsedData.declarations[declaration] == null) {
        parsedData.declarations[declaration] = new Set();
      }
      parsedData.declarations[declaration].add(reference);

      parsedData.references[reference] = declaration;
    }
  }
}