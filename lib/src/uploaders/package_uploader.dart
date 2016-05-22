library crossdart.uploaders.package_uploader;

import 'dart:async';
import 'dart:io';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/storage.dart';
import 'package:tasks/utils.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:crossdart/src/package_info.dart';

Logger _logger = new Logger("package_uploader");

class PackageUploader {
  final Config config;
  final Storage storage;
  PackageUploader(this.config, this.storage);

  Future<Null> uploadErroredPackage(PackageInfo packageInfo) async {
    _logger.info("Uploading error log file for $packageInfo to GCS");
    var logFile = new File(p.join(packageInfo.logPath(config)));
    return storage.insertFile(packageInfo.logUrl(config), logFile);
  }

  Future<Null> uploadSuccessfulPackages(Iterable<PackageInfo> packageInfos) async {
    for (var packageInfo in packageInfos) {
      _logger.info("Uploading package files $packageInfo to GCS");
      var entities = await new Directory(packageInfo.absolutePath(config)).list(recursive: true).toList();
      await pmap(entities.where((e) => e is File), (entity) {
        var relative = entity.path.replaceFirst("${packageInfo.absolutePath(config)}/", "");
        var path = p.join(config.gcsPrefix, packageInfo.name, packageInfo.version.toString(), relative);
        return storage.insertFile(path, entity);
      }, concurrencyCount: 20);
    }
  }
}
