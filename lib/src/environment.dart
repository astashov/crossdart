library crossdart.environment;

import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/parser.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/version.dart';
import 'package:path/path.dart' as path;
import 'package:sqljocky/sqljocky.dart';
import 'package:crossdart/src/store.dart';

class Environment {
  final Package package;
  final Iterable<CustomPackage> customPackages;
  final Sdk sdk;
  final Map<String, Package> packagesByFiles;
  final Parser parser;
  final Config config;
  final SendPort sender;

  const Environment(this.config, this.package, this.sender, this.customPackages, this.sdk, this.packagesByFiles, this.parser);

  Iterable<Package> get packages {
    return []..add(sdk)..addAll(customPackages);
  }
}


Future<Environment> buildEnvironment(Config config, PackageInfo mainPackageInfo, SendPort sender) async {
  var sdkPackageInfo = new PackageInfo(config, "sdk", new Version(config.sdk.sdkVersion));
  var sdk = new Sdk(config, sdkPackageInfo, await _getPackageId(sdkPackageInfo));

  var customPackages = [];
  for (var name in (new Directory(config.packagesPath).listSync(recursive: false))) {
    var packageName =  path.basename(path.dirname(name.resolveSymbolicLinksSync()));
    var match = new RegExp(r"-([a-zA-Z0-9\.+-]+)$").firstMatch(packageName);
    var version;
    if (match != null) {
      version = new Version(match[1]);
      packageName = packageName.replaceAll(new RegExp(r"-([a-zA-Z0-9\.+-]+)$"), "");
    }

    var packageInfo = new PackageInfo(config, packageName, version);
    customPackages.add(new CustomPackage(config, packageInfo, await _getPackageId(packageInfo)));
  }


  var packages = []..add(sdk)..addAll(customPackages);
  var packagesByFiles = packages.fold({}, (memo, package) {
    package.files.forEach((file) {
      memo[file.path] = package;
    });
    return memo;
  });

  var package = customPackages.firstWhere((cp) => cp.packageInfo == mainPackageInfo);
  return new Environment(config, package, sender, customPackages, sdk, packagesByFiles, new Parser.build(config, packages));
}

Future<int> _getPackageId(PackageInfo packageInfo) async {
  var id = await getPackageId(packageInfo);
  if (id == null) {
    id = await storePackage(packageInfo);
  }
  return id;
}