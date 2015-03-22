library crossdart.service;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

var _logger = new Logger("service");

String _getUrl(int page) => "https://pub.dartlang.org/packages.json?page=${page}";

Future<Iterable<String>> getAvailablePackages() async {
  _logger.info("Retrieving available packages...");
  var page = 1;
  var packages = new Set();

  var json;
  do {
    json = await http.get(_getUrl(page)).then((r) => JSON.decode(r.body));
    page += 1;
    var pageOfPackages = await Future.wait(json["packages"].map((packageUrl) {
      return http.get(packageUrl).then((r) => JSON.decode(r.body));
    }));
    packages.addAll(pageOfPackages);
  } while (page < 2);

  _logger.info("The number of the available packages - ${packages.length}");
  return packages.map((p) => p["name"]);
}