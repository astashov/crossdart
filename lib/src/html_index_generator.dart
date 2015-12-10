library crossdart.html_index_generator;

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/html/url.dart';
import 'package:crossdart/src/google_analytics.dart' as ga;
import 'package:path/path.dart';
import 'package:logging/logging.dart';

var _logger = new Logger("html_index_generator");

class HtmlIndexGenerator {
  final Config _config;
  final Iterable<Iterable<Package>> _generatedPackages;

  const HtmlIndexGenerator(this._config, this._generatedPackages);

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
          <div class="info">
            <div class="info--last-update">Last update: ${_currentDate}</div>
            <div class="info--github"><a href="https://github.com/astashov/crossdart">GitHub</a></div>
            <div class="info--chrome">
              <a href="https://chrome.google.com/webstore/detail/crossdart-chrome-extensio/jmdjoliiaibifkklhipgmnciiealomhd">Chrome GitHub Extension</a>
              (<a href="http://crossdart.info/demo.html">Demo</a>)
            </div>
          </div>
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
    new File(join(_config.outputPath, "index.html")).writeAsStringSync(content);

    new File(join(_config.templatesPath, "style.css")).copySync(join(_config.outputPath, "style.css"));
    ["index", "package", "code", "404"].forEach((name) {
      Process.runSync("cp", [join(_config.templatesPath, "$name.js"), join(_config.outputPath, "$name.js")]);
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

  String get _currentDate {
    return new DateFormat.yMMMMd().format(new DateTime.now());
  }

  void generatePackagePages() {
    _generatedPackages.forEach((packages) {
      if (packages.isNotEmpty) {
        _logger.info("Generating page of the ${packages.first.name} package");
        var content = """
          <!doctype html>
          <html lang="en-us" >
            <head>
              ${_scripts}
              <title>Pub ${packages.first.name} | ${_title}</title>
            </head>
            <body class="package-page">
              <h1 class="header"><a href='/'>CrossDart</a> - package '<span class='package-name'>${packages.first.name}</span>'</h1>
              <div class="top">
                <a class="link-to-pub" href="${packages.first.pubUrl}">Link to Pub</a>
                <span class="versions">Versions: ${_versions(packages)}</span>
              </div>
              <div class="files">${_packagesVersionsHtml(packages)}</div>
              <script src="/package.js"></script>
              ${ga.script}
            </body>
          </html>
        """;

        new File(join(_config.outputPath, PATH_PREFIX, packages.first.name, "index.html")).writeAsStringSync(content);
      }
    });
  }

  String _versions(Iterable<Package> packages) {
    var sortedPackages = packages.toList();
    sortedPackages.sort((a, b) => b.version.compareTo(a.version));
    return sortedPackages.map((package) {
      return "<span class='version' data-version='${package.version}'>${package.version}</span>";
    }).join("\n");
  }

  String _packagesHtml() {
    return _generatedPackages.map((packages) {
      if (packages.isNotEmpty) {
        var package = packages.first;
        return "<a class='package' href='${packageIndexUrl(package.packageInfo, shouldAddVersion: false)}'>${package.name}</a>";
      } else {
        return "";
      }
    }).join("\n");
  }

  String _packagesVersionsHtml(Iterable<Package> packages) {
    return packages.map((package) {
      var content = "<div class='files-version' data-version='${package.version}'>";
      content += "<div class='files-version--description'>${package.description}</div>";
      content += "<ul class='files-version--files'>";
      content += package.packageInfo.generatedPaths(_config).map((filePath) {
        return "<li class='files-version-file'><a href='${filePath}.html'>${filePath}</a></li>";
      }).join("\n");
      content += "</ul>";
      content += "</li>";
      content += "</div>";
      return content;
    }).join("\n");
  }

}
