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
import 'package:logging/logging.dart' as logging;

var _logger = new logging.Logger("parser");

ParsedData parseFile(String file) {
  _logger.info("Parsing file $file");
  var resolvedUnit = parser.getCompilationUnit(file);
  var visitor = new _ASTVisitor(file);
  resolvedUnit.accept(visitor);
  return visitor.parsedData;
}

class Parser {

  AnalysisContext _analysisContext;
  AnalysisContext get analysisContext {
    if (_analysisContext == null) {
      var resolvers = [
          new DartUriResolver(config.sdk),
          new PackageUriResolver([new JavaFile(config.packagesPath)]),
          new FileUriResolver()];

      _analysisContext = AnalysisEngine.instance.createAnalysisContext();
      _analysisContext.sourceFactory = new SourceFactory(resolvers);
      _analysisContext.applyChanges(changeSet);
    }
    return _analysisContext;
  }

  Iterable<File> _files;
  Iterable<File> get files {
    if (_files == null) {
      _files = packages.map((p) => p.files).expand((i) => i);
    }
    return _files;
  }

  ChangeSet _changeSet;
  ChangeSet get changeSet {
    if (_changeSet == null) {
      _changeSet = new ChangeSet();
      files.forEach((File f) {
        Source s = new FileBasedSource.con1(new JavaFile(f.path));
        _changeSet.addedSource(s);
      });
    }
    return _changeSet;
  }

  Map<String, LibraryElement> _librariesByParts;
  Map<String, LibraryElement> get librariesByParts {
    if (_librariesByParts == null) {
      _librariesByParts = files.fold({}, (Map<String, LibraryElement> memo, File f) {
        Source s = new FileBasedSource.con1(new JavaFile(f.path));
        var libElement = analysisContext.computeLibraryElement(s);
        if (libElement != null) {
          libElement.parts.map((p) => p.toString()).forEach((part) {
            memo[part] = libElement;
          });
        }
        return memo;
      });
    }
    return _librariesByParts;
  }

  CompilationUnit getCompilationUnit(String file) {
    Source source = new FileBasedSource.con1(new JavaFile(file));
    var library = analysisContext.computeLibraryElement(source);
    if (library.name == "") {
      library = librariesByParts[file];
    }
    return analysisContext.resolveCompilationUnit(source, library);
  }
}

Parser parser = new Parser();


class _ASTVisitor extends GeneralizingAstVisitor {
  String file;

  _ASTVisitor(this.file);

  ParsedData _parsedData = new ParsedData();
  ParsedData get parsedData => _parsedData;

  visitNode(AstNode node) {
    super.visitNode(node);
    //print("Node ${node}, type: ${node.runtimeType}");
  }

  visitSimpleStringLiteral(SimpleStringLiteral node) {
    super.visitSimpleStringLiteral(node);
    if (node.parent is PartDirective) {
      var reference = new e.Reference(this.file, name: node.toString(), offset: node.offset, end: node.end);
      var declaration = new e.Import((node.parent as PartDirective).element.source.fullName);
      _addReferenceAndDeclaration(reference, declaration);
    } else if (node.parent is ImportDirective) {
      var reference = new e.Reference(this.file, name: node.toString(), offset: node.offset, end: node.end);
      var declaration = new e.Import((node.parent as ImportDirective).element.importedLibrary.definingCompilationUnit.source.fullName);
      _addReferenceAndDeclaration(reference, declaration);
    }
  }

  visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);
    if (node.parent != null && node.parent.parent is PartOfDirective) {
      PartOfDirective partOfNode = node.parent.parent;
      var reference = new e.Reference(this.file, name: node.toString(), offset: node.offset, end: node.end);
      var declaration = new e.Import(partOfNode.element.source.fullName);
      _addReferenceAndDeclaration(reference, declaration);
    }
    Element element = node.bestElement;
//    print("Node ${node}, type: ${node.runtimeType}, parent: ${node.parent.runtimeType}, library: ${element != null ? element.library : null}");
    if (element != null && element.library != null && element.node is Declaration && !node.inDeclarationContext()) {
      var reference = new e.Reference(this.file, name: node.bestElement.displayName, offset: node.offset, end: node.end);
      var declarationElement = (element.node as Declaration).element;
      var declaration = new e.Declaration(declarationElement.source.fullName,
          name: declarationElement.displayName,
          offset: element.node.offset,
          end: element.node.end);

      _addReferenceAndDeclaration(reference, declaration);
    }
  }

  void _addReferenceAndDeclaration(e.Reference reference, e.Declaration declaration) {
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