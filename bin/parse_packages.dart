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
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/store.dart';
import 'package:crossdart/src/parser.dart';
import 'package:crossdart/src/installer/installer.dart';
import 'package:crossdart/src/util/iterable.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:crossdart/src/isolate_events.dart';
import 'package:quiver/iterables.dart';

Logger _logger = new Logger("parse");

Future main(args) async {
  var parsePackagesArgs = new ParsePackagesArgs(args);
  if (!parsePackagesArgs.runChecks()) {
    return;
  }
  var results = parsePackagesArgs.results;

  var config = new Config(
      sdkPath: new File(results[Config.SDK_PATH]).resolveSymbolicLinksSync(),
      installPath: new File(results[Config.INSTALL_PATH]).resolveSymbolicLinksSync(),
      isDbUsed: true,
      part: results[Config.PART],
      dbLogin: results[Config.DB_LOGIN],
      dbPassword: results[Config.DB_PASSWORD],
      dbHost: results[Config.DB_HOST],
      dbPort: results[Config.DB_PORT],
      dbName: results[Config.DB_NAME]);

  logging.initialize();
  await runParser(config);
  deallocDbPool();
  exit(0);
}

Future runParser(Config config) async {
//  var packageInfos = [
//      //new PackageInfo(config, "stagexl", new Version("0.9.2+1"))
//      //new PackageInfo(config, "dagre", new Version("0.0.2"))
//      new PackageInfo("dnd", new Version("0.2.1")),
//      //new PackageInfo("pool", new Version("1.0.1"))
//      ];
  List<PackageInfo> packageInfos = (await getUpdatedPackages(config)).toList();
  var erroredPackageInfos = await dbPool(config).query("""
    SELECT package_name AS name, package_version AS version FROM errors
  """);
  erroredPackageInfos = (await erroredPackageInfos.toList()).map((p) {
    return new PackageInfo(p.name, new Version(p.version));
  });
  erroredPackageInfos.forEach((packageInfo) {
    packageInfos.remove(packageInfo);
  });
  (await new DbPackageLoader(config).getAllPackageInfos()).forEach((packageInfo) {
    packageInfos.remove(packageInfo);
  });

  packageInfos = inGroups(packageInfos, config.totalParts).toList()[config.currentPart - 1];

  var index = 0;
  for (Iterable<PackageInfo> packageInfoTuple in zip(inGroups(packageInfos, 4).where((i) => i.length > 0))) {
    var tupleIndex = 0;
    var futures = packageInfoTuple.map((PackageInfo packageInfo) {
      _logger.info("Handling package ${packageInfo.name} (${packageInfo.version}) - ${index}/${packageInfos.length}");
      Timer timer;
      var newInstallPath = config.installPath + "-$tupleIndex";
      var newPackagesPath = p.join(newInstallPath, "packages");
      var newConfig = config.copy(installPath: newInstallPath, packagesPath: newPackagesPath);
      tupleIndex += 1;
      index += 1;
      return _runIsolate(_analyze, [newConfig, packageInfo, tupleIndex], (isolate, msg, completer) {
        _logger.fine("Received a message - ${msg}");
        if (msg == IsolateEvent.FINISH) {
          if (timer != null) {
            timer.cancel();
            timer = null;
          }
          isolate.kill(Isolate.IMMEDIATE);
          completer.complete(msg);
        } else if (msg == IsolateEvent.START_FILE_PARSING) {
          _logger.fine("Setting a timer");
          if (timer != null) {
            timer.cancel();
          }
          timer = new Timer(new Duration(seconds: 90), () {
            _logger.warning("Timeout while waiting for parsing a file, skipping this package");
            isolate.kill(Isolate.IMMEDIATE);
            completer.completeError("timeout");
          });
        } else if (msg == IsolateEvent.FINISH_FILE_PARSING && timer != null) {
          timer.cancel();
          timer = null;
        } else if (msg == IsolateEvent.ERROR) {
          if (timer != null) {
            timer.cancel();
            timer = null;
          }
          isolate.kill(Isolate.IMMEDIATE);
          completer.completeError("error");
        }
      }).catchError((exception, stackTrace) {
        return storeError(config, packageInfo, exception, stackTrace).then((_) {
          if (exception != "timeout" && exception != "error") {
            throw exception;
          }
        });
      });
    });
    await Future.wait(futures);
  };
}

Future _runIsolate(Function isolateFunction, input, void callback(Isolate isolate, message, Completer completer)) {
  var receivePort = new ReceivePort();
  var completer = new Completer();

  Isolate.spawn(isolateFunction, receivePort.sendPort).then((isolate) {
    receivePort.listen((msg) {
      if (msg is SendPort) {
        msg.send(input);
      } else {
        callback(isolate, msg, completer);
      }
    });
  });

  return completer.future.then((v) {
    receivePort.close();
    return v;
  });
}

void _runInIsolate(SendPort sender, void callback(data)) {
  var receivePort = new ReceivePort();
  sender.send(receivePort.sendPort);
  receivePort.listen((data) {
    callback(data);
  });
}

Future _analyze(SendPort sender) async {
  _runInIsolate(sender, await (List data) async {
    Config config = data[0];
    PackageInfo packageInfo = data[1];
    int index = data[2];
    logging.initialize(index);
    try {
      sender.send(IsolateEvent.START);
      if (!(await (new DbPackageLoader(config).doesPackageExist(packageInfo)))) {
        new Installer(config, packageInfo).install();
        var environment = await buildEnvironment(config, packageInfo, sender);
        await storeDependencies(environment, environment.package);
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
