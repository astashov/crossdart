library crossdart.installer.installer;

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:path/path.dart' as p;

var _logger = new Logger("installer");

class InstallerError implements Exception {
  final String message;
  InstallerError(this.message);
}

class Installer {
  PackageInfo _packageInfo;
  Config _config;

  Installer(this._config, this._packageInfo);

  void install() {
    _destroyCurrentlyExistingOutputDirectory();
    _createOutputDirectory();
    //_switchToOutputDirectory();
    _initializeProject();
    _runPub();
  }

  void _destroyCurrentlyExistingOutputDirectory() {
    _logger.info("Deleting the directory ${_config.installPath}");
    if (new Directory(_config.installPath).existsSync()) {
      new Directory(_config.installPath).deleteSync(recursive: true);
    }
  }

  void _createOutputDirectory() {
    _logger.info("Creating new directory ${_config.installPath}");
    new Directory(_config.installPath).createSync(recursive: true);
  }

  void _initializeProject() {
    _logger.info("Creating new project for package ${_packageInfo.name} ${_packageInfo.version} in ${_config.installPath}");
    var file = new File(p.join(_config.installPath, "pubspec.yaml"));
    file.writeAsStringSync("""
name: crossdart_example
description: CrossDart example
dependencies:
  ${_packageInfo.name}: ${_packageInfo.version}
  barback: any
  stack_trace: any""");
  }

  void _runPub() {
    _logger.info("Creating pubget");
    var pubgetPath = p.join(_config.installPath, "pubget");
    var file = new File(pubgetPath);
    file.writeAsStringSync("""#!/bin/bash
cd ${_config.installPath}
pub get
""");
    Process.runSync("chmod", ["+x", pubgetPath]);

    _logger.info("Running pubget");
    var commandName;
    if (Process.runSync("which", ["gtimeout"]).stdout != "") {
      commandName = "gtimeout";
    } else {
      commandName = "timeout";
    }
    var result = Process.runSync(commandName, ["30", pubgetPath]);
    sleep(new Duration(seconds: 1));
    if (result.stdout != "") {
      _logger.info("Output - ${result.stdout}");
    }
    if (result.stderr != "") {
      _logger.info("Error - ${result.stderr}");
      throw new InstallerError("Install error - ${result.stderr}");
    }
  }
}