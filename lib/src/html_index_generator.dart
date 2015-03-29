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
          ${_scripts}
          <title>${_title}</title>
        </head>

        <body class="index-page">
          <h1 class="header">CrossDart</h1>
          <h2 class="subheader">Cross-referenced Dart's pub packages</h2>
          <div class="search input-field">
            <input type="text" id="search" value="">
            <label for="search">Search by package name</label>
          </div>
          <ul class="packages">
            ${_packagesHtml()}
          </ul>
        </body>
      </html>
    """;
    new File(join(config.htmlPath, "index.html")).writeAsStringSync(content);
    new File(join(config.templatesPath, "style.css")).copySync(join(config.htmlPath, "style.css"));
  }

  String get _scripts {
    return """
      <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/materialize/0.95.3/css/materialize.min.css">
      <link rel="stylesheet" href="/style.css" type="text/css">
      <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.1.3/jquery.min.js"></script>
      <script src="https://cdnjs.cloudflare.com/ajax/libs/materialize/0.95.3/js/materialize.min.js"></script>
      <script src="/index.js"></script>
    """;
  }

  String get _title {
    return "CrossDart - cross-referenced Dart's pub packages";
  }

  void generatePackagePages() {
    getGeneratedPackageInfos().forEach((packageInfos) {
      _logger.info("Generating page of the ${packageInfos.first.name} package");
      var content = """
        <!doctype html>
        <html lang="en-us" >
          <head>
            ${_scripts}
            <title>Pub ${packageInfos.first.name} | ${_title}</title>
          </head>
          <body class="package-page">
            <h1 class="header"><a href='/'>CrossDart</a> - package '<span class='package-name'>${packageInfos.first.name}</span>'</h1>
            <div class="versions">Versions: ${_versions(packageInfos)}</div>
            <div class="files">${_packagesVersionsHtml(packageInfos)}</div>
          </body>
        </html>
      """;

      new File(join(config.htmlPath, packageInfos.first.name, "index.html")).writeAsStringSync(content);
    });
  }

  String _versions(Iterable<PackageInfo> packageInfos) {
    return packageInfos.map((packageInfo) {
      return "<span class='version' data-version='${packageInfo.version}'>${packageInfo.version}</span>";
    }).join("\n");
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
      var content = "<div class='files-version' data-version='${packageInfo.version}'>";
      content += "<ul>";
      content += packageInfo.generatedPaths.map((filePath) {
        return "<li class='files-version-file'><a href='${filePath}.html'>${filePath}</a></li>";
      }).join("\n");
      content += "</ul>";
      content += "</li>";
      return content;
    }).join("\n");
  }

}