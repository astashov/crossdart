library crossdart.parser;

import 'dart:io';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/scanner.dart';

import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/isolate_events.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/entity.dart' as e;
import 'package:logging/logging.dart' as logging;

var _logger = new logging.Logger("parser");

ParsedData parseFile(Environment environment, String file) {
  _logger.info("Parsing file $file");
  environment.sender.send(IsolateEvent.START_FILE_PARSING);
  var resolvedUnit = environment.parser.getCompilationUnit(file);
  if (resolvedUnit != null) {
    var visitor = new _ASTVisitor(environment, file);
    resolvedUnit.accept(visitor);
    environment.sender.send(IsolateEvent.FINISH_FILE_PARSING);
    return visitor.parsedData;
  } else {
    _logger.warning("Wasn't be able to resolve unit, giving up...");
    environment.sender.send(IsolateEvent.FINISH_FILE_PARSING);
    return new ParsedData();
  }
}

class Parser {
  final AnalysisContext _analysisContext;
  final Map<String, LibraryElement> _librariesByParts;

  const Parser(this._analysisContext, this._librariesByParts);

  factory Parser.build(Config config, Iterable<Package> packages) {
    var resolvers = [
        new DartUriResolver(config.sdk),
        new PackageUriResolver([new JavaFile(config.packagesPath)]),
        new FileUriResolver()];

    var analysisContext = AnalysisEngine.instance.createAnalysisContext();
    analysisContext.sourceFactory = new SourceFactory(resolvers);

    var files = packages.map((p) => p.files).expand((i) => i);
    var changeSet = new ChangeSet();
    files.forEach((File f) {
      Source s = new FileBasedSource.con1(new JavaFile(f.path));
      changeSet.addedSource(s);
    });
    analysisContext.applyChanges(changeSet);

    var librariesByParts = files.fold({}, (Map<String, LibraryElement> memo, File f) {
      Source s = new FileBasedSource.con1(new JavaFile(f.path));
      var libElement = analysisContext.computeLibraryElement(s);
      if (libElement != null) {
        libElement.parts.map((p) => p.toString()).forEach((part) {
          memo[part] = libElement;
        });
      }
      return memo;
    });

    return new Parser(analysisContext, librariesByParts);
  }

  CompilationUnit getCompilationUnit(String file) {
    Source source = new FileBasedSource.con1(new JavaFile(file));
    var library = _librariesByParts[file];
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

class _ASTVisitor extends GeneralizingAstVisitor {
  static const KEYWORD = "keyword";
  static const DECLARATION = "declaration";
  static const ANNOTATION = "annotation";
  static const STRING = "string";

  Environment environment;
  String file;

  _ASTVisitor(this.environment, this.file);

  ParsedData _parsedData = new ParsedData();
  ParsedData get parsedData => _parsedData;

  visitNode(AstNode node) {
    super.visitNode(node);
    //print("Node ${node}, type: ${node.runtimeType}, beginToken: ${node.beginToken}, endToken: ${node.endToken}");
  }

  visitDirective(Directive node) {
    super.visitDirective(node);
    _addToken(KEYWORD, node.keyword);
  }

  visitComment(Comment node) {
    super.visitComment(node);
    _addToken(node.runtimeType.toString().toLowerCase(), node.beginToken, node.endToken);
  }

  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);
    if (node.abstractKeyword != null) {
      _addToken(KEYWORD, node.abstractKeyword);
    }
    _addToken(KEYWORD, node.classKeyword);
  }

  visitExtendsClause(ExtendsClause node) {
    super.visitExtendsClause(node);
    _addToken(KEYWORD, node.keyword);
  }

  visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);
    [node.externalKeyword, node.modifierKeyword, node.operatorKeyword, node.propertyKeyword].forEach((keyword) {
      if (keyword != null) {
        _addToken(KEYWORD, keyword);
      }
    });

    _addToken(DECLARATION, node.name.token);
  }

  visitPartOfDirecive(PartOfDirective node) {
    super.visitPartOfDirective(node);
    _addToken(KEYWORD, node.partToken, node.ofToken);
  }

  visitConstructorDeclaration(ConstructorDeclaration node) {
    super.visitConstructorDeclaration(node);
    [node.externalKeyword, node.constKeyword, node.factoryKeyword].forEach((keyword) {
      if (keyword != null) {
        _addToken(KEYWORD, keyword);
      }
    });
    if (node.name != null) {
      _addToken(DECLARATION, node.name.token);
    }
  }

  visitSuperExpression(SuperExpression node) {
    super.visitSuperExpression(node);
    _addToken(KEYWORD, node.beginToken);
  }

  visitReturnStatement(ReturnStatement node) {
    super.visitReturnStatement(node);
    _addToken(KEYWORD, node.keyword);
  }

  visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    _addToken(KEYWORD, node.keyword);
  }

  visitAnnotation(Annotation node) {
    super.visitAnnotation(node);
    _addToken(ANNOTATION, node.beginToken, node.endToken);
  }

  visitSimpleStringLiteral(SimpleStringLiteral node) {
    super.visitSimpleStringLiteral(node);
    _addToken(STRING, node.literal);
    try {
      var parent = node.parent;
      if (parent is PartDirective) {
        var reference = new e.Reference(this.environment, this.file, name: node.toString(), offset: node.offset, end: node.end);
        var declaration = new e.Import(this.environment, parent.element.source.fullName);
        _addReferenceAndDeclaration(reference, declaration);
      } else if (parent is ImportDirective) {// && parent.element != null) {
        var reference = new e.Reference(this.environment, this.file, name: node.toString(), offset: node.offset, end: node.end);
        var declaration = new e.Import(this.environment, parent.element.importedLibrary.definingCompilationUnit.source.fullName);
        _addReferenceAndDeclaration(reference, declaration);
      }
    } catch(error, stackTrace) {
      _logger.severe("Error parsing simple string literal $node", error, stackTrace);
    }
  }

  visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);
    if (node.parent != null && node.parent.parent is PartOfDirective) {
      try {
        PartOfDirective partOfNode = node.parent.parent;
        var reference = new e.Reference(this.environment, this.file, name: node.toString(), offset: node.offset, end: node.end);
        var declaration = new e.Import(this.environment, partOfNode.element.source.fullName);
        _addReferenceAndDeclaration(reference, declaration);
      } catch(error, stackTrace) {
        _logger.severe("Error parsing 'part of' node $node", error, stackTrace);
      }
    } else {
      try {
        Element element = node.bestElement;
        if (element != null && element.library != null && element.node is Declaration && !node.inDeclarationContext()) {
          var reference = new e.Reference(this.environment, this.file, name: node.bestElement.displayName, offset: node.offset, end: node.end);
          var declarationElement = (element.node as Declaration).element;
          var declaration = new e.Declaration(this.environment, declarationElement.source.fullName,
              name: declarationElement.displayName,
              offset: element.node.offset,
              end: element.node.end);

          _addReferenceAndDeclaration(reference, declaration);
        }
      } catch(error, stackTrace) {
        _logger.severe("Error parsing a reference/declaration $node", error, stackTrace);
      }
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

  void _addToken(String name, Token beginToken, [Token endToken]) {
    var offset = beginToken.offset;
    var end = endToken == null ? beginToken.end : endToken.end;
    var newToken = new e.Token(this.environment, this.file, name: name, offset: offset, end: end);

    parsedData.tokens.add(newToken);
    if (parsedData.files[newToken.location.file] == null) {
      parsedData.files[newToken.location.file] = new Set();
    }
    parsedData.files[newToken.location.file].add(newToken);
  }
}