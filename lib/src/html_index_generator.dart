library crossdart.html_index_generator;

import 'dart:io';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/location.dart';
import 'package:path/path.dart';
import 'package:logging/logging.dart';

var _logger = new Logger("generator");

class HtmlIndexGenerator {
  Iterable<PackageInfo> _packageInfos;

  HtmlIndexGenerator(this._packageInfos);

  void generate() {
    _logger.info("Generating index page");
    var content = """
      <!doctype html>
      <html lang="en-us" >
        <head>
          <title>CrossDart - cross-referenced Dart's pub packages</title>
        </head>
        <body>
          <h1 class="header">CrossDart - cross-referenced Dart's pub packages</h1>
          <h2 class="subheader">List of packages</h2>
          <ul class="packages">
            ${_packagesHtml()}
          </ul>
        </body>
      </html>
    """;
    new File(join(config.htmlPath, "index.html")).writeAsStringSync(content);
  }

  String _packagesHtml() {
    return _packageInfos.map((packageInfo) {
      var content = "<li class='package'>";
      content += "<div class='package-name'>${packageInfo.name} (${packageInfo.version})</div>";
      content += "<ul class='package-files'>";
      packageInfo.generatedPaths.forEach((filePath) {
        content += "<li class='package-file'><a href='${filePath}.html'>${filePath}</a></li>";
      });
      content += "</ul>";
      content += "</li>";
      return content;
    }).join("\n");
  }
}