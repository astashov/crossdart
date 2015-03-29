library crossdart.parser;

import 'dart:io';
import 'dart:collection';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/scanner.dart';

import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/entity.dart' as e;
import 'package:logging/logging.dart' as logging;

var _logger = new logging.Logger("parser");

ParsedData parseFile(String file) {
  _logger.info("Parsing file $file");
  var parsedData = new ParsedData();
  var resolvedUnit = parser.getCompilationUnit(file);
  if (resolvedUnit != null) {
    var visitor = new _ASTVisitor(file);
//    var token = resolvedUnit.beginToken;
//    while (token != resolvedUnit.endToken) {
//      if (token.precedingComments != null) {
//        print("${token.precedingComments.runtimeType} - ${token.precedingComments}");
//      }
//      print("${token.runtimeType} - ${token}");
//      token = token.next;
//    }
    resolvedUnit.accept(visitor);
    return visitor.parsedData;
  } else {
    _logger.warning("Wasn't be able to resolve unit, giving up...");
    return new ParsedData();
  }
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
        analysisContext.computeLibraryElement(s);
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
      if (library == null) {
        var pathsWithLibraries = analysisContext.getLibrariesContaining(source);
        if (pathsWithLibraries.isNotEmpty) {
          library = analysisContext.computeLibraryElement(pathsWithLibraries.first);
        }
      }
    }
    return analysisContext.resolveCompilationUnit(source, library);
  }
}

Parser parser = new Parser();


class _ASTVisitor extends GeneralizingAstVisitor {
  static const KEYWORD = "keyword";
  static const DECLARATION = "declaration";
  static const ANNOTATION = "annotation";
  static const STRING = "string";

  String file;

  _ASTVisitor(this.file);

  ParsedData _parsedData = new ParsedData();
  ParsedData get parsedData => _parsedData;

//  visitNode(AstNode node) {
//    super.visitNode(node);
//    print("Node ${node}, type: ${node.runtimeType}, beginToken: ${node.beginToken}, endToken: ${node.endToken}");
//  }

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
      if (node.parent is PartDirective) {
        var reference = new e.Reference(this.file, name: node.toString(), offset: node.offset, end: node.end);
        var declaration = new e.Import((node.parent as PartDirective).element.source.fullName);
        _addReferenceAndDeclaration(reference, declaration);
      } else if (node.parent is ImportDirective) {
        var reference = new e.Reference(this.file, name: node.toString(), offset: node.offset, end: node.end);
        var declaration = new e.Import((node.parent as ImportDirective).element.importedLibrary.definingCompilationUnit.source.fullName);
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
        var reference = new e.Reference(this.file, name: node.toString(), offset: node.offset, end: node.end);
        var declaration = new e.Import(partOfNode.element.source.fullName);
        _addReferenceAndDeclaration(reference, declaration);
      } catch(error, stackTrace) {
        _logger.severe("Error parsing 'part of' node $node", error, stackTrace);
      }
    } else {
      try {
        Element element = node.bestElement;
        if (element != null && element.library != null && element.node is Declaration && !node.inDeclarationContext()) {
          var reference = new e.Reference(this.file, name: node.bestElement.displayName, offset: node.offset, end: node.end);
          var declarationElement = (element.node as Declaration).element;
          var declaration = new e.Declaration(declarationElement.source.fullName,
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
    var newToken = new e.Token(this.file, name: name, offset: offset, end: end);

    parsedData.tokens.add(newToken);
    if (parsedData.files[newToken.location.file] == null) {
      parsedData.files[newToken.location.file] = new Set();
    }
    parsedData.files[newToken.location.file].add(newToken);
  }
}