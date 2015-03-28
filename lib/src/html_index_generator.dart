library crossdart.html_index_generator;

import 'dart:io';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/version.dart';
import 'package:path/path.dart';
import 'package:logging/logging.dart';

var _logger = new Logger("generator");

class HtmlIndexGenerator {
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

  void generatePackagePages() {
    getGeneratedPackageInfos().forEach((packageInfos) {
      _logger.info("Generating page of the ${packageInfos.first.name} package");
      var content = """
        <!doctype html>
        <html lang="en-us" >
          <head>
            <title>Pub ${packageInfos.first.name} | CrossDart - cross-referenced Dart's pub packages</title>
          </head>
          <body>
            <h1 class="header">${packageInfos.first.name}</h1>
            <h2 class="subheader">List of versions</h2>
            <ul class="versions">
              ${_packagesVersionsHtml(packageInfos)}
            </ul>
          </body>
        </html>
      """;

      new File(join(config.htmlPath, packageInfos.first.name, "index.html")).writeAsStringSync(content);
    });
  }

  String _packagesHtml() {
    return getGeneratedPackageInfos().map((packageInfos) {
      var packageInfo = packageInfos.first;
      var content = "<li class='package'>";
      content += "<div class='package-name'><a href='/${packageInfo.name}'>${packageInfo.name}</a></div>";
      content += "</li>";
      return content;
    }).join("\n");
  }

  String _packagesVersionsHtml(Iterable<PackageInfo> packageInfos) {
    return packageInfos.map((packageInfo) {
      var content = "<li class='version'>";
      content += "<div class='version-name'>${packageInfo.version}</div>";
      content += "<ul>";
      content += packageInfo.generatedPaths.map((filePath) {
        return "<li class='version-file'><a href='${filePath}.html'>${filePath}</a></li>";
      }).join("\n");
      content += "</ul>";
      content += "</li>";
      return content;
    }).join("\n");
  }

}