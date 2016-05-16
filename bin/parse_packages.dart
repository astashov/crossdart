#!/usr/bin/env dart

library parse_packages;

import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/args.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/src/service.dart';
import 'package:crossdart/src/store/db_package_loader.dart';
import 'package:crossdart/src/store.dart';
import 'package:crossdart/src/parser.dart';
import 'package:crossdart/src/installer/installer.dart';
import 'package:crossdart/src/util/iterable.dart';
import 'package:logging/logging.dart';
import 'package:crossdart/src/isolate_events.dart';
import 'package:quiver/iterables.dart';
import 'package:crossdart/src/util/isolate.dart';
import 'package:crossdart/src/version.dart';

Logger _logger = new Logger("parse");

Future main(args) async {
  var parsePackagesArgs = new ParsePackagesArgs(args);
  if (!parsePackagesArgs.runChecks()) {
    return;
  }
  var results = parsePackagesArgs.results;

  var config = new Config.buildFromFiles(dirroot: results[Config.DIR_ROOT], isDbUsed: true, part: results[Config.PART]);

  logging.initialize();
  await runParser(config);
  deallocDbPool();
  exit(0);
}

Future runParser(Config config) async {
  var packageInfos = [
      //new PackageInfo(config, "stagexl", new Version("0.9.2+1"))
      //new PackageInfo(config, "dagre", new Version("0.0.2"))
      //new PackageInfo("dnd", new Version("0.2.0")),
      new PackageInfo("pool", new Version("1.0.1"))
      ];
  //List<PackageInfo> packageInfos = (await getAllPackages(config)).toList();
  (await new DbPackageLoader(config).getErroredPackageInfos()).forEach((packageInfo) {
    packageInfos.remove(packageInfo);
  });
  (await new DbPackageLoader(config).getAllPackageInfos()).forEach((packageInfo) {
    packageInfos.remove(packageInfo);
  });

  packageInfos = inGroups(packageInfos, config.totalParts).toList()[config.currentPart - 1].toList();

  await parallelRunner(
      zip(inGroups(packageInfos, 1).where((i) => i.length > 0)),
      _analyze,
      (int index, int tupleIndex, PackageInfo packageInfo) {
        _logger.info("Handling package ${packageInfo.name} (${packageInfo.version}) - ${index}/${packageInfos.length}");
        var newInstallPath = config.installPath + "-$tupleIndex";
        var newConfig = config.copy(installPath: newInstallPath);
        return [newConfig, packageInfo, tupleIndex];
      },
      logger: _logger,
      onError: (exception, stackTrace, PackageInfo packageInfo) {
        return storeError(config, packageInfo, exception, stackTrace).then((_) {
          if (exception != "timeout" && exception != "error") {
            throw exception;
          }
        });
      },
      onMessage: (Isolate isolate, IsolateEvent msg, Completer completer, List<Timer> timer) {
        if (msg == IsolateEvent.FINISH && timer.isNotEmpty) {
          timer[0].cancel();
          timer.removeLast();
        } else if (msg == IsolateEvent.FINISH_FILE_PARSING && timer.isNotEmpty) {
          timer[0].cancel();
          timer.removeLast();
        } else if (msg == IsolateEvent.ERROR && timer.isNotEmpty) {
          timer[0].cancel();
          timer.removeLast();
        } else if (msg == IsolateEvent.START_FILE_PARSING) {
          _logger.fine("Setting a timer");
          if (timer.isNotEmpty) {
            timer[0].cancel();
            timer.removeLast();
          }
          timer.add(new Timer(new Duration(seconds: 240), () {
            _logger.warning("Timeout while waiting for parsing a file, skipping this package");
            isolate.kill(priority: Isolate.IMMEDIATE);
            completer.completeError("timeout");
          }));
        }
      }
  );
}

Future _analyze(SendPort sender) async {
  runInIsolate(sender, await (List data) async {
    Config config = data[0];
    PackageInfo packageInfo = data[1];
    int index = data[2];
    logging.initialize(index);
    try {
      sender.send(IsolateEvent.START);
      if (!(await (new DbPackageLoader(config).doesPackageExist(packageInfo)))) {
        new Installer(config, packageInfo).install();
        var environment = await buildEnvironment(config, packageInfo, sender);
        var parsedData = await new Parser(environment).parsePackages();
        await store(environment, parsedData);
        deallocDbPool();
      }
      sender.send(IsolateEvent.FINISH);
    } catch(exception, stackTrace) {
      _logger.severe("Exception while handling a package ${packageInfo.name} ${packageInfo.version}", exception, stackTrace);
      await storeError(config, packageInfo, exception, stackTrace);
      deallocDbPool();
      sender.send(IsolateEvent.ERROR);
    }
  });
}
