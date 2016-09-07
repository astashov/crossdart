library crossdart.parser.ast_visitor;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/entity.dart' as e;
import 'package:logging/logging.dart' as logging;

var _logger = new logging.Logger("parser");

class ASTVisitor extends GeneralizingAstVisitor {
  static const KEYWORD = "keyword";
  static const DECLARATION = "declaration";
  static const ANNOTATION = "annotation";
  static const STRING = "string";

  Environment _environment;
  String _absolutePath;

  ASTVisitor(this._environment, this._absolutePath, this._parsedData);

  ParsedData _parsedData;
  ParsedData get parsedData => _parsedData;

  @override
  visitNode(AstNode node) {
    super.visitNode(node);
    //print("Node ${node}, type: ${node.runtimeType}, beginToken: ${node.beginToken}, endToken: ${node.endToken}");
  }

  @override
  visitSimpleStringLiteral(SimpleStringLiteral node) {
    super.visitSimpleStringLiteral(node);
    try {
      var parent = node.parent;
      if (parent is PartDirective) {
        var reference = new e.Reference(new Location.fromEnvironment(_environment, _absolutePath), name: node.toString(), offset: node.offset, end: node.end);
        var path;
        if ((parent as PartDirective).element != null) {
          path = (parent as PartDirective).element.source.uri.path;
        } else {
          path = (parent as PartDirective).source.uri.path;
        }
        var declaration = new e.Import(new Location.fromEnvironment(_environment, path));
        _addReferenceAndDeclaration(reference, declaration);
      } else if (parent is ImportDirective && (parent as ImportDirective).element != null) {
        var reference = new e.Reference(new Location.fromEnvironment(_environment, _absolutePath), name: node.toString(), offset: node.offset, end: node.end);
        var fullName = ((parent as ImportDirective).element as ImportElement).importedLibrary.definingCompilationUnit.source.fullName;
        var declaration = new e.Import(new Location.fromEnvironment(_environment, fullName));
        _addReferenceAndDeclaration(reference, declaration);
      } else if (parent is ExportDirective && (parent as ExportDirective).element != null) {
        var reference = new e.Reference(new Location.fromEnvironment(_environment, _absolutePath), name: node.toString(), offset: node.offset, end: node.end);
        var declaration = new e.Import(new Location.fromEnvironment(_environment, ((parent as ExportDirective).element as ExportElement).exportedLibrary.definingCompilationUnit.source.fullName));
        _addReferenceAndDeclaration(reference, declaration);
      }
    } catch(error, stackTrace) {
      _logger.severe("Error parsing simple string literal $node", error, stackTrace);
    }
  }

  @override
  visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);
    if (node.parent != null && node.parent.parent is PartOfDirective) {
      try {
        PartOfDirective partOfNode = node.parent.parent;
        var reference = new e.Reference(new Location.fromEnvironment(_environment, _absolutePath), name: node.toString(), offset: node.offset, end: node.end);
        var declaration = new e.Import(new Location.fromEnvironment(_environment, partOfNode.element.source.fullName));
        _addReferenceAndDeclaration(reference, declaration);
      } catch(error, stackTrace) {
        _logger.severe("Error parsing 'part of' node $node", error, stackTrace);
      }
    } else {
      try {
        Element element = node.bestElement;

        //print("Node ${node}, type: ${node.runtimeType}, bestElement - ${node.bestElement}, bestElementType - ${node.bestElement.runtimeType}, nodeType - ${node.bestElement.node.runtimeType}");

        if (element != null && element.library != null) {
          AstNode elementNode;
          if (element.computeNode() == null && element is PropertyAccessorElement) {
            elementNode = element.variable.computeNode();
          } else if (element.computeNode() == null && element is FieldFormalParameterElement) {
            elementNode = element.field.computeNode();
          } else {
            elementNode = element.computeNode();
          }

          if (elementNode is Declaration && !node.inDeclarationContext()) {
            var reference = new e.Reference(new Location.fromEnvironment(_environment, _absolutePath), name: node.bestElement.displayName, offset: node.offset, end: node.end);
            var declarationElement = elementNode.element;
            var kind = _getEntityKind(declarationElement);
            var declarationToken = _getDeclarationToken(elementNode);
            if (kind == null) {
              print("MISSING KIND! - ${declarationElement.runtimeType} - ${declarationElement.displayName}, ${declarationToken.offset}-${declarationToken.end}");
            }

            String contextName;
            if (declarationElement is ClassMemberElement) {
              contextName = declarationElement.enclosingElement.name;
            }

            var declaration = new e.Declaration(new Location.fromEnvironment(_environment, declarationElement.source.fullName),
                name: declarationElement.displayName,
                contextName: contextName,
                offset: declarationToken.offset,
                end: declarationToken.end,
                kind: kind);

            //print("Saved");
            _addReferenceAndDeclaration(reference, declaration);
          }
        }
      } catch(error, stackTrace) {
        _logger.severe("Error parsing a reference/declaration $node", error, stackTrace);
      }
    }
  }

  e.EntityKind _getEntityKind(Element declarationElement) {
    if (declarationElement is ClassElement) {
      return e.EntityKind.CLASS;
    } else if (declarationElement is MethodElement) {
      return e.EntityKind.METHOD;
    } else if (declarationElement is LocalVariableElement) {
      return e.EntityKind.LOCAL_VARIABLE;
    } else if (declarationElement is FunctionElement) {
      return e.EntityKind.FUNCTION;
    } else if (declarationElement is PropertyAccessorElement) {
      return e.EntityKind.PROPERTY_ACCESSOR;
    } else if (declarationElement is ConstructorElement) {
      return e.EntityKind.CONSTRUCTOR;
    } else if (declarationElement is FieldElement) {
      return e.EntityKind.FIELD;
    } else if (declarationElement is FunctionTypeAliasElement) {
      return e.EntityKind.FUNCTION_TYPE_ALIAS;
    } else if (declarationElement is TopLevelVariableElement) {
      return e.EntityKind.TOP_LEVEL_VARIABLE;
    } else {
      return null;
    }
  }

  AstNode _getDeclarationToken(dynamic node) {
    if ((node is ClassDeclaration
        || node is MethodDeclaration
        || node is VariableDeclaration
        || node is FunctionDeclaration
        || node is ConstructorDeclaration
        || node is EnumDeclaration
        || node is EnumConstantDeclaration
        || node is FunctionTypeAlias
        || node is ClassTypeAlias) && node.name != null) {
      return node.name;
    } else if (node is DeclaredIdentifier) {
      return node.identifier;
    } else if (node is ConstructorDeclaration && node.returnType != null) {
      return node.returnType;
    } else {
      print("Unknown declaration token - $node");
      print(node.runtimeType);
      return node;
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
