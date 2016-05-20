library crossdart.pub_retriever;

import 'dart:async';
import 'dart:convert';

import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/util/retry.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:crossdart/src/version.dart';

final _logger = new Logger("pub_retriever");

String _getUrl(int page) => "https://pub.dartlang.org/packages.json?page=$page";

class PubRetriever {
  List<PackageInfo> _currentList = [];
  Iterable<PackageInfo> get currentList => _currentList;

  Map<String, List<PackageInfo>> _packagesByName = {};
  Map<String, Iterable<PackageInfo>> get packagesByName => _packagesByName;

  PubRetriever();

  Future<List<PackageInfo>> update() async {
    _logger.info("Retrieving available packages...");
    var page = 1;

    var json;
    do {
      _logger.info("Retrieving page $page");
      json = await retry(() => http.get(_getUrl(page)).then((r) => JSON.decode(r.body)));
      page += 1;
      var pageOfPackageInfos = await Future.wait(json["packages"].map((packageUrl) {
        return retry(() => http.get(packageUrl).then((r) => JSON.decode(r.body)));
      }));
      var packages = pageOfPackageInfos.map((packageMap) {
        return packageMap["versions"].map((version) {
          return new PackageInfo(packageMap["name"], new Version(version));
        });
      }).expand((i) => i);
      if (packages.every((p) => _currentList.contains(p))) {
        break;
      } else {
        packages.forEach((package) {
          if (!_currentList.contains(package)) {
            _currentList.add(package);
            if (_packagesByName[package.name] == null) {
              _packagesByName[package.name] = [];
            }
            _packagesByName[package.name].add(package);
          }
        });
      }
    //} while (json["next"] != null);
    } while (page < 2);

    _logger.info("The number of the available packages - ${_currentList.length}");
    return new List.from(_currentList);
  }
}
