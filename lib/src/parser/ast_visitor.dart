library crossdart.parser.ast_visitor;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/scanner.dart';

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
  visitDirective(Directive node) {
    super.visitDirective(node);
    _addToken(KEYWORD, node.keyword);
  }

  @override
  visitComment(Comment node) {
    super.visitComment(node);
    _addToken(node.runtimeType.toString().toLowerCase(), node.beginToken, node.endToken);
  }

  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);
    if (node.abstractKeyword != null) {
      _addToken(KEYWORD, node.abstractKeyword);
    }
    _addToken(KEYWORD, node.classKeyword);
  }

  @override
  visitExtendsClause(ExtendsClause node) {
    super.visitExtendsClause(node);
    _addToken(KEYWORD, node.extendsKeyword);
  }

  @override
  visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);
    [node.externalKeyword, node.modifierKeyword, node.operatorKeyword, node.propertyKeyword].forEach((keyword) {
      if (keyword != null) {
        _addToken(KEYWORD, keyword);
      }
    });

    _addToken(DECLARATION, node.name.token);
  }

  @override
  visitPartOfDirective(PartOfDirective node) {
    super.visitPartOfDirective(node);
    _addToken(KEYWORD, node.partKeyword, node.ofKeyword);
  }

  @override
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

  @override
  visitSuperExpression(SuperExpression node) {
    super.visitSuperExpression(node);
    _addToken(KEYWORD, node.beginToken);
  }

  @override
  visitReturnStatement(ReturnStatement node) {
    super.visitReturnStatement(node);
    _addToken(KEYWORD, node.returnKeyword);
  }

  @override
  visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    _addToken(KEYWORD, node.keyword);
  }

  @override
  visitAnnotation(Annotation node) {
    super.visitAnnotation(node);
    _addToken(ANNOTATION, node.beginToken, node.endToken);
  }

  @override
  visitSimpleStringLiteral(SimpleStringLiteral node) {
    super.visitSimpleStringLiteral(node);
    _addToken(STRING, node.literal);
    try {
      var parent = node.parent;
      if (parent is PartDirective) {
        var reference = new e.Reference(new Location.fromEnvironment(_environment, _absolutePath), name: node.toString(), offset: node.offset, end: node.end);
        var declaration = new e.Import(new Location.fromEnvironment(_environment, (parent as PartDirective).element.source.fullName));
        _addReferenceAndDeclaration(reference, declaration);
      } else if (parent is ImportDirective && (parent as ImportDirective).element != null) {
        var reference = new e.Reference(new Location.fromEnvironment(_environment, _absolutePath), name: node.toString(), offset: node.offset, end: node.end);
        var declaration = new e.Import(new Location.fromEnvironment(_environment, (parent as ImportDirective).element.importedLibrary.definingCompilationUnit.source.fullName));
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

  void _addToken(String name, Token beginToken, [Token endToken]) {
    var offset = beginToken.offset;
    var end = endToken == null ? beginToken.end : endToken.end;
    var newToken = new e.Token(new Location.fromEnvironment(_environment, _absolutePath), name: name, offset: offset, end: end);

    parsedData.tokens.add(newToken);
    if (parsedData.files[newToken.location.file] == null) {
      parsedData.files[newToken.location.file] = new Set();
    }
    parsedData.files[newToken.location.file].add(newToken);
  }
}
