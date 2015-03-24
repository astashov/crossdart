library crossdart.installer.installer;

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:logging/logging.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package.dart';

var _logger = new Logger("installer");

class Installer {
  PackageInfo _packageInfo;

  Installer(this._packageInfo);

  void install() {
    _destroyCurrentlyExistingOutputDirectory();
    _createOutputDirectory();
    _switchToOutputDirectory();
    _initializeProject();
    _runPub();
  }

  void _destroyCurrentlyExistingOutputDirectory() {
    _logger.info("Deleting the directory ${config.installPath}");
    if (new Directory(config.installPath).existsSync()) {
      new Directory(config.installPath).deleteSync(recursive: true);
    }
  }

  void _createOutputDirectory() {
    _logger.info("Creating new directory ${config.installPath}");
    new Directory(config.installPath).createSync(recursive: true);
  }

  void _switchToOutputDirectory() {
    _logger.info("Setting current directory to ${config.installPath}");
    Directory.current = config.installPath;
  }

  void _initializeProject() {
    _logger.info("Creating new project for package ${_packageInfo.name} ${_packageInfo.version} in ${config.installPath}");
    var file = new File("pubspec.yaml");
    file.writeAsStringSync("""
      name: crossdart_example
      description: CrossDart example
      dependencies:
        ${_packageInfo.name}: ${_packageInfo.version}
    """);
  }

  void _runPub() {
    _logger.info("Running pub get");
    var result = Process.runSync("pub", ["get"]);
    sleep(new Duration(seconds: 1));
    if (result.stdout != "") {
      _logger.info("Output - ${result.stdout}");
    }
    if (result.stderr != "") {
      _logger.info("Error - ${result.stderr}");
    }
  }
}