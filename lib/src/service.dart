library crossdart.service;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/config.dart';
import 'package:path/path.dart';

var _logger = new Logger("service");

String _getUrl(int page) => "https://pub.dartlang.org/packages.json?page=${page}";

// TODO: Refactor to a class

Future<Iterable<PackageInfo>> getAllPackages(Config config) async {
  Iterable<PackageInfo> allPackages = _getPackagesFromFile(config);
  //Iterable<PackageInfo> allPackages = await _getPackagesFromPub(config);

  _logger.info("The number of retrieved packages - ${allPackages.length}");

  return allPackages;
}

Iterable<PackageInfo> _getPackagesFromFile(Config config) {
  var packages = JSON.decode(new File(join(config.currentDir, "packages.json")).readAsStringSync())
      .map((json) => new PackageInfo.fromJson(json));
  _logger.info("The number of the available packages - ${packages.length}");
  return packages;
}

Future<Iterable<PackageInfo>> _getPackagesFromPub(Config config) async {
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
    pageOfPackages.forEach((packageMap) {
      packageMap["versions"].forEach((version) {
        packages.add(new PackageInfo(packageMap["name"], new Version(version)));
      });
    });

  } while (json["next"] != null);
  //} while (page < 2);

  new File(join(config.currentDir, "packages.json")).writeAsStringSync(JSON.encode(packages.toList()));

  _logger.info("The number of the available packages - ${packages.length}");
  return packages;
}
