library crossdart.service;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/config.dart';
import 'package:path/path.dart';

var _logger = new Logger("service");

String _getUrl(int page) => "https://pub.dartlang.org/packages.json?page=${page}";

Future<Iterable<PackageInfo>> getAvailablePackages() {
  if (_arePackagesCached) {
    return new Future(_getPackagesFromFile);
  } else {
    return _getPackagesFromPub();
  }
}

bool get _arePackagesCached {
  return new File(join(config.htmlPath, "packages.json")).existsSync();
}

Iterable<PackageInfo> _getPackagesFromFile() {
  return JSON.decode(new File(join(config.htmlPath, "packages.json")).readAsStringSync())
      .map((json) => new PackageInfo.fromJson(json));
}

Future<Iterable<PackageInfo>> _getPackagesFromPub() async {
  _logger.info("Retrieving available packages...");
  var page = 1;
  var packages = new Set();

  var json;
  do {
    _logger.info("Retrieving page $page");
    json = await http.get(_getUrl(page)).then((r) => JSON.decode(r.body));
    page += 1;
    var pageOfPackages = await Future.wait(json["packages"].map((packageUrl) {
      return http.get(packageUrl).then((r) => JSON.decode(r.body));
    }));
    packages.addAll(pageOfPackages.map((p) => new PackageInfo(p["name"], new Version(p["versions"].last))));
  } while (json["next"] != null);
  //} while (page < 2);

  new File(join(config.htmlPath, "packages.json")).writeAsStringSync(JSON.encode(packages.toList()));

  _logger.info("The number of the available packages - ${packages.length}");
  return packages;
}
