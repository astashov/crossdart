library crossdart.generators.index_generator;

import 'dart:async';
import 'dart:io';

import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/util/iterable.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/google_analytics.dart' as ga;

var _logger = new Logger("index_generator");

class IndexGenerator {
  final Config config;
  IndexGenerator(this.config);

  Future<Null> generateErrors(Iterable<PackageInfo> packageInfos) async {
    Map<String, Iterable<PackageInfo>> groupedPackageInfos = groupBy(packageInfos, (p) => p.name);
    var html = new StringBuffer();
    html.writeln(_generateHeader(MenuItem.failed));
    html.writeln("<dl>");
    groupedPackageInfos.forEach((name, packageVersions) {
      List<PackageInfo> sortedPackageVersions = new List.from(packageVersions)..sort((a, b) => b.compareTo(a));
      html.writeln('<dt>${sortedPackageVersions.first.name}</dt><dd class="text-muted">');
      html.write(sortedPackageVersions.map((packageInfo) {
        return "<a href='/${packageInfo.urlRoot(config)}/log.txt'>${packageInfo.version}</a>";
      }).join(' &bull;\n'));
      html.writeln("</dd>");
    });
    html.writeln("</dl>");
    html.writeln(_generateFooter());
    await writeToFile(MenuItem.failed.url, html.toString());
  }

  Future<Null> generateHistory(Iterable<Package> successfulPackages, Iterable<PackageInfo> erroredPackages) async {
    var sortedPackages = []..addAll(successfulPackages)..addAll(erroredPackages)..sort((a, b) {
      return b.createdAt.compareTo(a.createdAt);
    });

    var html = new StringBuffer();
    html.writeln(_generateHeader(MenuItem.history));
    html.writeln("<table class='table table-hover'>");
    html.writeln("<thead><tr><th>Package</th><th>Time</th><th>Status</th><th>Log</th></thead>");
    html.writeln("<tbody>");
    sortedPackages.forEach((package) {
      var isSuccessful = package is Package;
      html.writeln("<tr${isSuccessful ? '' : ' class="danger"'}>");
      if (isSuccessful) {
        html.writeln("<td><a href='/${package.packageInfo.urlRoot(config)}/${package.paths.first}.html'>${package.dirname}</a></td>");
      } else {
        html.writeln("<td>${package.dirname}</td>");
      }
      html.writeln("<td>${package.createdAt}</td>");
      html.writeln("<td>${isSuccessful ? 'Success' : '<em>Failure</em>'}</td>");
      if (isSuccessful) {
        html.writeln("<td><a href='/${package.packageInfo.urlRoot(config)}/log.txt'>build log</a></td>");
      } else {
        html.writeln("<td><a href='/${package.urlRoot(config)}/log.txt'>build log</a></td>");
      }
      html.writeln("</tr>");
    });
    html.writeln("</tbody></table>");
    html.writeln(_generateFooter());
    await writeToFile(MenuItem.history.url, html.toString());
  }

  Future<Null> generateHome(Iterable<Package> packages) async {
    Map<String, Iterable<Package>> groupedPackages = groupBy(packages, (package) => package.name);
    var html = new StringBuffer();
    html.writeln(_generateHeader(MenuItem.home));
    html.writeln("<dl>");
    groupedPackages.forEach((name, packageVersions) {
      List<Package> sortedPackageVersions = new List.from(packageVersions)
        ..sort((a, b) => b.compareTo(a));
      html.writeln(
          '<dt>${sortedPackageVersions.first.name}</dt><dd class="text-muted">');
      html.write(sortedPackageVersions.map((package) {
        return "<a href='/${config.gcsPrefix}/${package.name}/${package.version}/${package.paths.first}.html'>${package.version}</a>";
      }).join(' &bull;\n'));
      html.writeln("</dd>");
    });
    html.writeln("</dl>");
    html.writeln(_generateFooter());
    await writeToFile(MenuItem.home.url, html.toString());
  }

  Future<Null> generate404() async {
    var html = new StringBuffer();
    html.writeln(_generateHeader());
    html.writeln("""
      <div class="row">
        <div class="col-md-12">
          <div class="jumbotron center">
              <h1>Page Not Found <small><font face="Tahoma" color="red">Error 404</font></small></h1>
              <br />
              <p>The page you requested could not be found. Its possible documentation was not built for the package
                requested. Check the <a href="/${MenuItem.failed.url}">build failures</a> page for your package.</p>
              <a href="/${MenuItem.home.url}" class="btn btn-lg btn-info"><i class="glyphicon glyphicon-home glyphicon-white"></i> dartdocs home</a>
            </div>
            <br />
        </div>
      </div>""");
    html.writeln(_generateFooter());
    await writeToFile("404.html", html.toString());
  }

  Future<Null> writeToFile(String filePath, String contents) async {
    var file = new File(path.join(config.outputPath, filePath));
    await file.create(recursive: true);
    await file.writeAsString(contents);
  }

  String _generateFooter() {
    return ga.script;
  }

  String _generateHeader([MenuItem activeItem]) {
    return """<html>
  <head>
    <title>Dartdocs - Documentation for Dart packages</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css">
  </head>
  <body>
    <nav class="navbar navbar-default" role="navigation">
      <div class="container-fluid">
        <ul class="nav navbar-nav">
          ${MenuItem.all.map((mi) => mi.toHtml(mi == activeItem)).join("\n")}
        </ul>
        <p class="navbar-text pull-right">
          <a href="https://github.com/astashov/dartdocs.org">Github</a> |
          <a href="https://github.com/astashov/dartdocs.org/issues">Issues</a>
        </p>
      </div>
    </nav>
    <div class="container">""";
  }
}

class MenuItem {
  static const MenuItem home = const MenuItem("index.html", "Home");
  static const MenuItem history =
  const MenuItem("history/index.html", "Build history");
  static const MenuItem failed =
  const MenuItem("failed/index.html", "Build failures");
  static const Iterable<MenuItem> all = const [home, history, failed];

  final String url;
  final String title;
  const MenuItem(this.url, this.title);

  String toHtml(bool isActive) {
    return "<li${isActive ? " class='active'" : ""}><a href='/$url'>$title</a></li>";
  }
}

final Iterable<String> allIndexUrls = []
  ..addAll(MenuItem.all.map((mi) => mi.url))
  ..add("index.json");
