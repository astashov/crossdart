#!/usr/bin/env dart

import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/logging.dart' as logging;
import 'package:crossdart/crossdart.dart';
import 'package:crossdart/src/service.dart';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/store.dart';
import 'package:logging/logging.dart';
import 'package:crossdart/src/db_pool.dart';
import 'package:crossdart/src/isolate_events.dart';

Logger _logger = new Logger("main");

Future main(args) async {
  var config = new Config.fromArgs(args);
  logging.initialize();

  var packageInfos = [
      //new PackageInfo(config, "stagexl", new Version("0.9.2+1"))
      new PackageInfo(config, "route", new Version("0.4.6"))
      //new PackageInfo("dnd", new Version.fromString("0.2.1"))
      ];
//  List<PackageInfo> packageInfos = (await getUpdatedPackages(config)).toList();
//  var erroredPackageInfos = await dbPool.query("SELECT package_name, package_version FROM errors");
//  erroredPackageInfos = (await erroredPackageInfos.toList()).map((p) {
//    return new PackageInfo(config, p.package_name, new Version(p.package_version));
//  });
//  erroredPackageInfos.forEach((packageInfo) {
//    packageInfos.remove(packageInfo);
//  });
//  config.generatedPackageInfos.expand((i) => i).forEach((packageInfo) {
//    packageInfos.remove(packageInfo);
//  });

  var index = 0;
  for (PackageInfo packageInfo in packageInfos) {
    _logger.info("Handling package ${packageInfo.name} (${packageInfo.version}) - ${index}/${packageInfos.length}");
    Timer timer;
    try {
      await runIsolate(analyze, [config, packageInfo], (isolate, msg, completer) {
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
          timer = new Timer(new Duration(seconds: 30), () {
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
      });
    } catch (exception, stackTrace) {
      await storeError(packageInfo, exception, stackTrace);
      if (exception != "timeout" && exception != "error") {
        rethrow;
      }
    }
    index += 1;
  };
  dbPool.close();
  generateIndexHtml(config);
  exit(0);
  return new Future.value();
}

Future runIsolate(Function isolateFunction, input, void callback(Isolate isolate, message, Completer completer)) {
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

void runInIsolate(SendPort sender, void callback(data)) {
  var receivePort = new ReceivePort();
  sender.send(receivePort.sendPort);
  receivePort.listen((data) {
    callback(data);
  });
}

Future analyze(SendPort sender) async {
  runInIsolate(sender, await (data) async {
    logging.initialize();
    var config = data[0];
    var packageInfo = data[1];
    try {
      sender.send(IsolateEvent.START);
      //install(config, packageInfo);
      var environment = await buildEnvironment(config, packageInfo, sender);
      await storeDependencies(environment, environment.package);
      var parsedData = await parse(environment);
      generatePackageHtml(environment, parsedData);
      await store(environment, parsedData);
      sender.send(IsolateEvent.FINISH);
    } catch(exception, stackTrace) {
      _logger.severe("Exception while handling a package ${packageInfo.name} ${packageInfo.version}", exception, stackTrace);
      await storeError(packageInfo, exception, stackTrace);
      sender.send(IsolateEvent.ERROR);
    }
  });
}