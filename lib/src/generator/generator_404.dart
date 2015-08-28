library crossdart.generator.generator_404;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:crossdart/src/store/db_package_loader.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package_info.dart';

class Generator404 {
  final Config _config;
  Generator404(this._config);

  Future<Null> generate() async {
    var dbPackageLoader = new DbPackageLoader(_config);
    var packageInfos = await dbPackageLoader.getAllPackageInfos();
    var erroredPackageInfos = await dbPackageLoader.getErroredPackageInfos();
    var packagesJson = JSON.encode(_packageInfosMap(packageInfos));
    var erroredPackagesJson = JSON.encode(_packageInfosMap(erroredPackageInfos));
    var html = """
<!doctype html>
<html lang="en-us">
  <head>
    <link rel="stylesheet" href="/style.css" type="text/css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/materialize/0.95.3/css/materialize.min.css">
    <title>CrossDart - Page Not Found</title>
  </head>

  <body class="page-404">
    <div class="content">
      <h3 class="header">Crossdart</h1>
      <div class="text">Page not found</div>
      <div class="tips"></div>
    </div>
    <div id="packages">${_escape(packagesJson)}</div>
    <div id="errored-packages">${_escape(erroredPackagesJson)}</div>

    <script src="/404.js"></script>
  </body>
</html>""";
    var file = new File(p.join(_config.outputPath, "404.html"));
    file.writeAsStringSync(html);
  }

  String _escape(String html) {
    return html
        .replaceAll("&", "&amp;")
        .replaceAll(">", "&gt;")
        .replaceAll("<", "&lt;");

  }

  Map<String, List<String>> _packageInfosMap(Iterable<PackageInfo> packageInfos) {
    return packageInfos.fold({}, (memo, pi) {
      if (memo[pi.name] == null) {
        memo[pi.name] = [];
      }
      memo[pi.name].add(pi.version.toString());
      memo[pi.name].sort();
      return memo;
    });
  }
}
