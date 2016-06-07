library crossdart.environment;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/config.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';
import 'package:package_config/discovery.dart' as packages_discovery;
import 'package:crossdart/src/version.dart';

Logger _logger = new Logger("environment");

class Environment {
  final Package package;
  final Iterable<CustomPackage> customPackages;
  final Sdk sdk;
  final Map<String, Package> packagesByFiles;
  final Config config;

  Environment(this.config, this.package, this.customPackages, this.sdk, this.packagesByFiles);

  Iterable<Package> get packages {
    return new Set()..add(sdk)..addAll(customPackages)..add(package);
  }
}

Future<Environment> buildEnvironment(Config config) async {
  _logger.info("Building environment");
  var sdkPackageInfo = new PackageInfo("sdk", new Version.parse(config.sdk.sdkVersion));

  var sdk = await buildSdkFromFileSystem(config, sdkPackageInfo);

  var customPackages = [];
  Map<String, Uri> packagesDiscovery;

  Package package;
  if (config.input == config.dartSdk) {
    package = sdk;
    packagesDiscovery = {};
  } else {
    package = buildProjectFromFileSystem(config);
    packagesDiscovery = (await packages_discovery.loadPackagesFile(new Uri.file(config.packagesPath))).asMap();
  }

  for (var name in packagesDiscovery.keys) {
    var dir = new Directory.fromUri(packagesDiscovery[name]).parent.path;
    if (config.input == null || !dir.contains(config.input)) {
      var version = path.basename(dir).replaceFirst("${name}-", "");
      var packageInfo = new PackageInfo(name, new Version.parse(version));
      var package = await buildCustomPackageFromFileSystem(config, packageInfo);
      customPackages.add(package);
    }
  }

  List<Package> packages = []..add(sdk)..addAll(customPackages);

  if (package is! Sdk) {
    packages.add(package);
  }

  var packagesByFiles = packages.fold({}, (Map<String, Package> memo, Package package) {
    package.absolutePaths.forEach((file) {
      memo[file] = package;
    });
    return memo;
  });

  _logger.info("Finished loading environment");
  return new Environment(config, package, customPackages, sdk, packagesByFiles);
}
