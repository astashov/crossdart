#!/usr/bin/env dart

library parse_packages;

import 'dart:io';
import 'dart:async';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/args.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/src/store/db_package_loader.dart';
import 'package:crossdart/src/store.dart';
import 'package:crossdart/src/parser.dart';
import 'package:crossdart/src/installer/installer.dart';
import 'package:logging/logging.dart';
import 'package:crossdart/src/pub_retriever.dart';
import 'package:crossdart/src/shard.dart';
import 'dart:math';
import 'package:crossdart/src/parsed_data.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/store/db_parsed_data_loader.dart';
import 'package:crossdart/src/html_package_generator.dart';
import 'package:crossdart/src/uploaders/package_uploader.dart';
import 'package:crossdart/src/storage.dart';
import 'package:crossdart/src/cleaners/package_cleaners.dart';

Logger _logger = new Logger("parse");

Future main(List<String> args) async {
  logging.initialize();

  var parsePackages = new _ParsePackages.build(args);

  while (true) {
    await parsePackages.initialize();
    var packages = await parsePackages.retrieveNextPackages();
    if (packages.isNotEmpty) {
      await parsePackages.handlePackages(packages);
    } else {
      _logger.info("Sleeping for 3 minutes...");
      await new Future.delayed(new Duration(minutes: 3));
    }
  }

  deallocDbPool();
  exit(0);
}

class _ParsePackages {
  final Config config;
  final PubRetriever pubRetriever;
  final DbPackageLoader dbPackageLoader;
  final DbParsedDataLoader dbParsedDataLoader;
  final Storage storage;
  final PackageUploader packageUploader;
  final PackageCleaner packageCleaner;

  int docsVersion;

  _ParsePackages(
      this.config,
      this.pubRetriever,
      this.dbPackageLoader,
      this.dbParsedDataLoader,
      this.storage,
      this.packageUploader,
      this.packageCleaner);

  factory _ParsePackages.build(List<String> args) {
    var parsePackagesArgs = new ParsePackagesArgs(args);
    if (!parsePackagesArgs.runChecks()) {
      exit(1);
    }
    var results = parsePackagesArgs.results;

    var config = new Config.buildFromFiles(dirroot: results[Config.DIR_ROOT], isDbUsed: true, part: results[Config.PART]);
    var storage = new Storage(config);
    return new _ParsePackages(
        config,
        new PubRetriever(),
        new DbPackageLoader(config),
        new DbParsedDataLoader(config),
        storage,
        new PackageUploader(config, storage),
        new PackageCleaner(config));
  }

  Future<Null> initialize() async {
    this.docsVersion = (await (await query(config, "SELECT id FROM crossdart_versions ORDER BY id DESC LIMIT 1")).first)[0];
  }

  Future<Iterable<PackageInfo>> retrieveNextPackages() async {
//  var packageInfos = [
//      //new PackageInfo(config, "stagexl", new Version("0.9.2+1"))
//      //new PackageInfo(config, "dagre", new Version("0.0.2"))
//      //new PackageInfo("dnd", new Version("0.2.0")),
//      new PackageInfo("pool", new Version("1.0.1"))
//      ];
    var packageInfos = await pubRetriever.update();
    (await dbPackageLoader.getErroredPackageInfos()).forEach((packageInfo) {
      packageInfos.remove(packageInfo);
    });
    var allPackageInfos = (await dbPackageLoader.getAllPackageInfos()).toSet();
    var generatedPackageInfos = (await dbPackageLoader.getGeneratedPackageInfos(docsVersion)).toSet();
    packageInfos.removeWhere((packageInfo) {
      return allPackageInfos.contains(packageInfo) && generatedPackageInfos.contains(packageInfo);
    });
    _logger.info("The number of the new packages - ${packageInfos.length}");
    var shard = await getShard(config);
    _logger.info("Shard: $shard");
    var shardedPackages = shard.part(packageInfos);
    return shardedPackages.getRange(0, min(20, shardedPackages.length));
  }

  Future<Null> handlePackages(Iterable<PackageInfo> packageInfos) async {
    for (var packageInfo in packageInfos) {
      try {
        config.currentDate = new DateTime.now().toUtc();
        ParsedData parsedData;
        Set<Package> packages;
        if (!(await dbPackageLoader.doesPackageExist(packageInfo))) {
          new Installer(config, packageInfo).install();
          var environment = await buildEnvironment(config, packageInfo, null);
          parsedData = await new Parser(environment).parsePackages(dbParsedDataLoader);
          packages = environment.packages.toSet();
          await store(environment, parsedData);
        }
        if (!(await dbPackageLoader.doesGeneratedPackageExist(packageInfo))) {
          if (parsedData == null || packages == null) {
            var packageInfos = await dbPackageLoader.getPackageInfoDependencies(packageInfo);
            packages = new Set();
            for (var pi in packageInfos) {
              Package package;
              try {
                package = await buildFromDatabase(config, pi);
              } on InstallerError catch (_, __) {
                package = null;
              }
              if (package != null) {
                packages.add(package);
              }
            }
            parsedData = await dbParsedDataLoader.load(packages);
            print(packageInfos.toList());
            print(packages.map((p) => p.packageInfo).toList());
          }
          var generatedPackageInfos = (await dbPackageLoader.getGeneratedPackageInfos(docsVersion)).toSet();
          packages.removeWhere((p) => generatedPackageInfos.contains(p.packageInfo));
          packages = (await Future.wait(packages.map((p) => p.updateId()))).toSet();
          new HtmlPackageGenerator(config, packages, parsedData).generate();
          await storeGeneratedPackage(config, docsVersion, packages.map((p) => p.packageInfo));
          await packageUploader.uploadSuccessfulPackages(packages.map((p) => p.packageInfo));
          packageCleaner.deleteSync();
        }
      } catch (exception, stackTrace) {
        _logger.severe("Exception while handling a package ${packageInfo.name} ${packageInfo.version}", exception, stackTrace);
        await storeError(config, packageInfo, exception, stackTrace);
      }
    }
  }
}

//Future _analyze(SendPort sender) async {
//  runInIsolate(sender, await (List data) async {
//    Config config = data[0];
//    PackageInfo packageInfo = data[1];
//    int index = data[2];
//    logging.initialize(index);
//    try {
//      sender.send(IsolateEvent.START);
//      ParsedData parsedData;
//      Set<Package> packages;
//      if (!(await (new DbPackageLoader(config).doesPackageExist(packageInfo)))) {
//        new Installer(config, packageInfo).install();
//        var environment = await buildEnvironment(config, packageInfo, sender);
//        parsedData = await new Parser(environment).parsePackages();
//        packages = environment.packages.toSet();
//        await store(environment, parsedData);
//      }
//      if (!(await (new DbPackageLoader(config).doesGeneratedPackageExist(packageInfo)))) {
//        if (parsedData == null || packages == null) {
//          var packageInfos = await new DbPackageLoader(config).getPackageInfoDependencies(packageInfo);
//          packages = new Set();
//          for (var pi in packageInfos) {
//            Package package;
//            try {
//              package = await buildFromFileSystem(config, pi);
//            } on InstallerError catch (_, __) {
//              package = null;
//            }
//            if (package != null) {
//              packages.add(package);
//            }
//          }
//          parsedData = await (new DbParsedDataLoader(config).load(packages));
//        }
//        new HtmlPackageGenerator(config, packages, parsedData).generate();
//      }
//      deallocDbPool();
//      sender.send(IsolateEvent.FINISH);
//    } catch(exception, stackTrace) {
//      _logger.severe("Exception while handling a package ${packageInfo.name} ${packageInfo.version}", exception, stackTrace);
//      await storeError(config, packageInfo, exception, stackTrace);
//      deallocDbPool();
//      sender.send(IsolateEvent.ERROR);
//    }
//  });
//}
