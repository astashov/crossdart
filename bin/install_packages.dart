#!/usr/bin/env dart

library install_packages;

import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/args.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/src/store/db_package_loader.dart';
import 'package:crossdart/src/store.dart';
import 'package:crossdart/src/installer/installer.dart';
import 'package:crossdart/src/util/iterable.dart';
import 'package:logging/logging.dart';
import 'package:crossdart/src/isolate_events.dart';
import 'package:crossdart/src/util/isolate.dart';

Logger _logger = new Logger("parse");

Future main(args) async {
  var installPackagesArgs = new InstallPackagesArgs(args);
  if (!installPackagesArgs.runChecks()) {
    return;
  }
  var results = installPackagesArgs.results;

  var config = new Config(
      sdkPath: new File(results[Config.SDK_PATH]).resolveSymbolicLinksSync(),
      installPath: new File(results[Config.INSTALL_PATH]).resolveSymbolicLinksSync(),
      pubCachePath: new File(results[Config.PUB_CACHE_PATH]).resolveSymbolicLinksSync(),
      isDbUsed: true,
      dbLogin: results[Config.DB_LOGIN],
      dbPassword: results[Config.DB_PASSWORD],
      dbHost: results[Config.DB_HOST],
      dbPort: results[Config.DB_PORT],
      dbName: results[Config.DB_NAME]);

  logging.initialize();
  await runInstaller(config);
  deallocDbPool();
  exit(0);
}

Future runInstaller(Config config) async {
  var dbPackageLoader = new DbPackageLoader(config);
  var erroredPackageInfos = await dbPackageLoader.getErroredPackageInfos();
  List<PackageInfo> packageInfos = (await dbPackageLoader.getAllPackageInfos()).where((p) {
    return !p.isSdk && p.getDirectoryInPubCache(config) == null && !erroredPackageInfos.contains(p);
  }).toList();

  await parallelRunner(
      inGroupsOf(packageInfos, 2).where((i) => i.length > 0),
      _install,
      (int index, int tupleIndex, PackageInfo packageInfo) {
        _logger.info("Handling package ${packageInfo.name} (${packageInfo.version}) - ${index}/${packageInfos.length}");
        var newInstallPath = config.installPath + "-$tupleIndex";
        var newConfig = config.copy(installPath: newInstallPath);
        return [newConfig, packageInfo, tupleIndex];
      },
      logger: _logger,
      onError: (exception, stackTrace, PackageInfo packageInfo) {
        return storeError(config, packageInfo, exception, stackTrace);
      }
  );
}

Future _install(SendPort sender) async {
  runInIsolate(sender, await (List data) async {
    Config config = data[0];
    PackageInfo packageInfo = data[1];
    int index = data[2];
    logging.initialize(index);
    try {
      sender.send(IsolateEvent.START);
      String directory = packageInfo.getDirectoryInPubCache(config);
      if (directory == null) {
        new Installer(config, packageInfo).install();
      } else {
        _logger.info("The package ${packageInfo} is already installed.");
      }
      sender.send(IsolateEvent.FINISH);
    } catch(exception, stackTrace) {
      _logger.severe("Exception while handling a package ${packageInfo.name} ${packageInfo.version}", exception, stackTrace);
      await storeError(config, packageInfo, exception, stackTrace);
      sender.send(IsolateEvent.ERROR);
    }
  });
}
