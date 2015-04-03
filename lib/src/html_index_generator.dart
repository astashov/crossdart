library crossdart.html_index_generator;

import 'dart:io';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/google_analytics.dart' as ga;
import 'package:crossdart/src/package.dart';
import 'package:path/path.dart';
import 'package:logging/logging.dart';

var _logger = new Logger("generator");

class HtmlIndexGenerator {
  final Config _config;

  const HtmlIndexGenerator(this._config);

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
          <div class="packages">
            ${_packagesHtml()}
          </div>
          <script src="/index.js"></script>
          ${ga.script}
        </body>
      </html>
    """;
    new File(join(_config.htmlPath, "index.html")).writeAsStringSync(content);

    new File(join(_config.templatesPath, "style.css")).copySync(join(_config.htmlPath, "style.css"));
    ["index", "package"].forEach((name) {
      Process.runSync("dart2js", ["-o", join(_config.htmlPath, "$name.js"), join(_config.templatesPath, "$name.dart")]);
    });
  }

  String get _scripts {
    return """
      <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/materialize/0.95.3/css/materialize.min.css">
      <link rel="stylesheet" href="/style.css" type="text/css">
      <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.1.3/jquery.min.js"></script>
      <script src="https://cdnjs.cloudflare.com/ajax/libs/materialize/0.95.3/js/materialize.min.js"></script>
    """;
  }

  String get _title {
    return "CrossDart - cross-referenced Dart's pub packages";
  }

  void generatePackagePages() {
    _config.generatedPackageInfos.forEach((packageInfos) {
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
            <script src="/package.js"></script>
            ${ga.script}
          </body>
        </html>
      """;

      new File(join(_config.htmlPath, packageInfos.first.name, "index.html")).writeAsStringSync(content);
    });
  }

  String _versions(Iterable<PackageInfo> packageInfos) {
    return packageInfos.map((packageInfo) {
      return "<span class='version' data-version='${packageInfo.version}'>${packageInfo.version}</span>";
    }).join("\n");
  }

  String _packagesHtml() {
    return _config.generatedPackageInfos.map((packageInfos) {
      var packageInfo = packageInfos.first;
      return "<a class='package' href='/${packageInfo.name}'>${packageInfo.name}</a>";
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
      content += "</div>";
      return content;
    }).join("\n");
  }

}