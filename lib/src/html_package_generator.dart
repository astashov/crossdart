library crossdart.html_package_generator;

import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:crossdart/src/location.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/cache.dart';
import 'package:crossdart/src/google_analytics.dart' as ga;
import 'package:path/path.dart' as p;
import 'package:logging/logging.dart';
import 'package:resource/resource.dart' as r;
import 'dart:async';

var _logger = new Logger("html_package_generator");

class HtmlPackageGenerator {
  ParsedData _parsedData;
  Iterable<Package> _packages;
  HtmlEscape sanitizer = const HtmlEscape();
  Config _config;
  Map<String, Package> _packagesByFiles = {};

  HtmlPackageGenerator(this._config, Iterable<Package> packages, this._parsedData) :
    _packages = packages,
    _packagesByFiles = packages.fold({}, (Map<String, Package> memo, Package package) {
      package.absolutePaths.forEach((file) {
        memo[file] = package;
      });
      return memo;
    });

  Future<Null> generateProject() async {
    _packagesByFiles.forEach((absolutePath, package) {
      Set<Entity> entities = this._parsedData.files[absolutePath];
      if (entities == null) {
        entities = new Set();
      }
      var location = new Location(_config, package, package.relativePath(absolutePath));
      entities = entities.where((e) => e.offset != null && e.end != null).toSet();
      var path = p.join(_config.output, location.writePath);
      var directory = new Directory(p.dirname(path));
      directory.createSync(recursive: true);
      var file = new File(path).openSync(mode: FileMode.WRITE);
      _writeContent(absolutePath, entities, file, package);
      file.closeSync();
    });

    String redirectUrl;
    if (_packages.length == 1 && _packages.first is Sdk) {
      redirectUrl = this._parsedData.files[_packages.first.absolutePath("lib/core/list.dart")].first.location.htmlPath;
    } else {
      redirectUrl = this._parsedData.references.keys.first.location.htmlPath;
    }
    new File(p.join(_config.output, "index.html")).writeAsStringSync("""
      <html>
        <head>
          <title>www.dartdocs.org</title>
          <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
          <meta http-equiv="Pragma" content="no-cache" />
          <meta http-equiv="Expires" content="0" />
          <meta http-equiv="refresh" content="0; url='${redirectUrl}'" />
          <script>
            var latestUrl = '${redirectUrl}';
            document.location = latestUrl;
          </script>
          </head>
        <body></body>
      </html>
    """);

    new Directory(p.join(_config.output, "assets")).createSync(recursive: true);
    for (var filename in ["code.js", "highlight.pack.js", "style.css"]) {
      var resource = new r.Resource("package:crossdart/resources/${filename}");
      new File(p.join(_config.output, "assets", filename)).writeAsStringSync(await resource.readAsString());
    }
  }

  String _addEntityStart(Entity entity) {
    if (entity is Reference) {
      var declaration = _parsedData.references[entity];
      var content = "<a href='${declaration.location.htmlPath}";
      if (declaration.lineNumber != null) {
        content += "#line-${declaration.lineNumber}";
      }
      content += "' class='entity__reference'>";
      return content;
    } else if (entity is Declaration) {
      return "<span id='declaration-${entity.id}' class='entity__declaration'>";
    } else {
      return "<span>";
    }
  }

  String _addEntityEnd(Entity entity) {
    if (entity is Reference) {
      return "</a>";
    } else {
      return "</span>";
    }
  }

  String _headerContent(String absolutePath, Package package) {
    var location = new Location(_config, package, package.relativePath(absolutePath));
    var baseList = new List.filled(location.path.split("/").length - 1, "..");
    return """
      <!doctype html>
      <html lang="en-us">
        <head>
          <title>'${package.name}' - ${location.path} | CrossDart - cross-referenced Dart's pub packages</title>
          <base href="${baseList.isNotEmpty ? baseList.join("/") : "."}">
          <link rel="stylesheet" href="assets/style.css" type="text/css">
          <meta name="viewport" content="width=device-width, initial-scale=1">
        </head>
        <body class='source-code'>
          <nav class='nav'>
            <a href='${_config.hostedUrl}' class='link-to-home'>Crossdart</a>
            <span class='nav-back'>${package.name} (${package.version})</span>
            <a class="link-to-pub" href="${package.pubUrl}">Link to Pub</a>
            <a class="link-to-docs" href="${package.docsUrl}">Link to Docs</a>
            <span class="nav--filetree-toggle">Filetree</span>
          </nav>
          <div class="content">
            <nav class="filetree">
              <div class="filetree--fuzzy-search">
                <input class="filetree--fuzzy-search--input" type="text" id="fuzzy-search"
                  value="" placeholder="Search by filename" />
              </div>
              ${_buildFileTree(package, location.path)}
              <div class="filetree--drag-handle"></div>
            </nav>
    """;
  }

  String _footerContent() {
    return """
        </div>
        <script src="assets/highlight.pack.js"></script>
        <script src="assets/code.js"></script>
        ${ga.script}
      </body>
      </html>
    """;
  }

  void _writeContent(String absolutePath, Set<Entity> entities, RandomAccessFile file, Package package) {
    _logger.info("Building content of ${absolutePath} (${package.packageInfo.dirname})");
    file.writeStringSync(_headerContent(absolutePath, package));
    file.writeStringSync("<div class='wrapper'><pre class='lines'>");
    for (var i = 0; i < cache.numberOfLines(absolutePath); i += 1) {
      file.writeStringSync("<a id='line-${i}' class='line'>${i + 1}</a>");
    }
    file.writeStringSync("</pre>");
    file.writeStringSync("<pre class='code'>");
    String fileContent = cache.fileContents(absolutePath);
    List<Entity> entitiesList = entities.toList()..sort((a, b) => Comparable.compare(a.offset, b.offset));

    var lastOffset = 0;
    Map<int, List<Entity>> stack = {};
    String newlineChar = cache.getNewlineChar(fileContent);

    Entity entity = entitiesList.isNotEmpty ? entitiesList.removeAt(0) : null;
    int nextNewlinePos = fileContent.indexOf(newlineChar, lastOffset);

    while(entity != null || stack.isNotEmpty || nextNewlinePos != null) {
      int entityStartPos = entity != null ? entity.offset : null;
      nextNewlinePos = fileContent.indexOf(newlineChar, lastOffset);
      nextNewlinePos = nextNewlinePos == -1 ? null : nextNewlinePos;
      int entityEndPos = stack.isNotEmpty ? stack.keys.reduce(math.min) : null;

      var positions = [entityStartPos, nextNewlinePos, entityEndPos].where((i) => i != null);
      if (positions.isNotEmpty) {
        int nextStop = positions.reduce(math.min);
        var string = fileContent.substring(lastOffset, nextStop);
        file.writeStringSync(sanitizer.convert(string));
        if (entityEndPos == nextStop || entityStartPos == nextStop) {
          if (entityEndPos == nextStop) {
            Entity referenceFromStack = stack[entityEndPos].removeLast();
            if (stack[entityEndPos].isEmpty) {
              stack.remove(entityEndPos);
            }
            file.writeStringSync(_addEntityEnd(referenceFromStack));
          }
          if (entityStartPos == nextStop) {
            if (stack[entity.end] == null) {
              stack[entity.end] = [];
            }
            stack[entity.end].add(entity);
            file.writeStringSync(_addEntityStart(entity));
            entity = entitiesList.isNotEmpty ? entitiesList.removeAt(0) : null;
          }
          lastOffset = nextStop;
        } else {
          if (nextNewlinePos == nextStop) {
            file.writeStringSync("\n");
            lastOffset = nextStop + newlineChar.length;
          } else {
            lastOffset = nextStop;
          }
        }
      } else {
        file.writeStringSync(sanitizer.convert(fileContent.substring(lastOffset)));
      }
    }

    file.writeStringSync("</pre></div>");
    file.writeStringSync(_footerContent());
  }

  String _buildFileTree(Package package, String currentPath) {
    return """<ul class="filetree--root">
      ${_buildFileTreeContents(package, _getFileTreeMap(package), currentPath.split("/"))}
    </ul>""";
  }

  String _buildFileTreeContents(Package package, Iterable<Object> fileTreeMap, Iterable<String> currentPathParts) {
    var sortedFileTreeMap = fileTreeMap.toList();
    sortedFileTreeMap.sort((a, b) {
      if (a is Map && b is! Map) {
        return -1;
      } else if (a is! Map && b is! Map) {
        return a.compareTo(b);
      } else if (a is Map && b is Map) {
        return a.keys.first.compareTo(b.keys.first);
      } else {
        return 1;
      }
    });
    return sortedFileTreeMap.map((node) {
      if (node is Map) {
        var key = node.keys.first;
        var isOpen = currentPathParts.isNotEmpty && currentPathParts.first == key;
        return """<li class="filetree--item filetree--item__directory${isOpen ? ' is-open' : ''}">
          <span class="filetree--item--info"><span class="filetree--item--fold-icon"></span><span class="filetree--item--title">${key}</span></span>
          <ul class="filetree--children">
            ${_buildFileTreeContents(package, node[key], isOpen ? currentPathParts.skip(1) : [])}
          </ul>
        </li>""";
      } else {
        var isCurrent = currentPathParts.isNotEmpty && currentPathParts.first == p.basename(node);
        var location = new Location(_config, package, node);
        var name = isCurrent
            ? p.basename(node)
            : "<a href='${location.path}.html'>${p.basename(node)}</a>";
        return """<li class="filetree--item filetree--item__file${isCurrent ? ' is-current' : ''}">
          <span class="filetree--item--info"><span class="filetree--item--title">${name}</span></span>
        </li>""";
      }
    }).join("\n");
  }

  Iterable<Object> _getFileTreeMap(Package package) {
    return package.paths.fold([], (memo, path) {
      var parts = path.split("/");
      var cursor = memo;
      for (var i = 0; i < parts.length; i += 1) {
        var part = parts[i];
        if (i == parts.length - 1) {
          cursor.add(path);
        } else {
          var existingMap = cursor.firstWhere((i) => i is Map && i.containsKey(part), orElse: () => null);
          if (existingMap == null) {
            existingMap = {part: []};
            cursor.add(existingMap);
          }
          cursor = existingMap[part];
        }
      }
      return memo;
    });
  }
}
