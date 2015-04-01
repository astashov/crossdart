library crossdart.environment;

import 'dart:io';
import 'dart:isolate';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/parser.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/version.dart';
import 'package:path/path.dart' as path;

class Environment {
  final Package package;
  final Iterable<CustomPackage> customPackages;
  final Sdk sdk;
  final Map<String, Package> packagesByFiles;
  final Parser parser;
  final Config config;
  final SendPort sender;

  const Environment(this.config, this.package, this.sender, this.customPackages, this.sdk, this.packagesByFiles, this.parser);

  factory Environment.build(Config config, Package package, SendPort sender) {
    var customPackages = new Directory(config.packagesPath).listSync(recursive: false).map((name) {
      var packageName =  path.basename(path.dirname(name.resolveSymbolicLinksSync()));
      var match = new RegExp(r"-([a-zA-Z0-9\.+-]+)$").firstMatch(packageName);
      var version;
      if (match != null) {
        version = new Version(match[1]);
        packageName = packageName.replaceAll(new RegExp(r"-([a-zA-Z0-9\.+-]+)$"), "");
      }
      return new CustomPackage(config, new PackageInfo(config, packageName, version));
    }).toList();

    var sdk = new Sdk(config, new PackageInfo(config, "sdk", new Version(config.sdk.sdkVersion)));

    var packages = []..add(sdk)..addAll(customPackages);
    var packagesByFiles = packages.fold({}, (memo, package) {
      package.files.forEach((file) {
        memo[file.path] = package;
      });
      return memo;
    });

    return new Environment(config, package, sender, customPackages, sdk, packagesByFiles, new Parser.build(config, packages));
  }

  Iterable<Package> get packages {
    return []..add(sdk)..addAll(customPackages);
  }
}