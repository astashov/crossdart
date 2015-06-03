library crossdart.environment;

import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/version.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

Logger _logger = new Logger("environment");

class Environment {
  final Package package;
  final Iterable<CustomPackage> customPackages;
  final Sdk sdk;
  final Map<String, Package> packagesByFiles;
  final Config config;
  final SendPort sender;

  Environment(this.config, this.package, this.sender, this.customPackages, this.sdk, this.packagesByFiles);

  Iterable<Package> get packages {
    return new Set()..add(sdk)..addAll(customPackages)..add(package);
  }
}

Future<Environment> buildEnvironment(Config config, [PackageInfo mainPackageInfo, SendPort sender]) async {
  _logger.info("Building environment");
  var sdkPackageInfo = new PackageInfo("sdk", new Version(config.sdk.sdkVersion));
  _copySdkToPackagesRoot(config);

  var sdk = await buildSdkFromFileSystem(config, sdkPackageInfo);

  var customPackages = [];
  for (var dir in (new Directory(config.packagesPath).listSync(recursive: false))) {
    var resolvedDir = dir.resolveSymbolicLinksSync();
    if (config.projectPath == null || !resolvedDir.contains(config.projectPath)) {
      var name = path.basename(dir.path);
      var version = path.basename(path.dirname(resolvedDir)).replaceFirst("${name}-", "");
      var packageInfo = new PackageInfo(name, new Version(version));
      customPackages.add(await buildCustomPackageFromFileSystem(config, packageInfo));
    }
  }

  List<Package> packages = []..add(sdk)..addAll(customPackages);

  var package;
  if (mainPackageInfo != null) {
    package = customPackages.firstWhere((cp) => cp.packageInfo == mainPackageInfo);
  } else {
    package = buildProjectFromFileSystem(config);
    packages.add(package);
  }

  var packagesByFiles = packages.fold({}, (Map<String, Package> memo, Package package) {
    package.absolutePaths.forEach((file) {
      memo[file] = package;
    });
    return memo;
  });

  _logger.info("Finished loading environment");
  return new Environment(config, package, sender, customPackages, sdk, packagesByFiles);
}

void _copySdkToPackagesRoot(Config config) {
  new Directory(config.sdkPackagesRoot).createSync(recursive: true);
  Process.runSync("cp", ["-r", config.sdkPath, path.join(config.sdkPackagesRoot, "sdk-${config.sdk.sdkVersion}")]);
}