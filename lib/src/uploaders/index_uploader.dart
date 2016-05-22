library crossdart.uploaders.index_uploader;

import 'dart:async';
import 'dart:io';

import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/index_generator.dart';
import 'package:crossdart/src/storage.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

Logger _logger = new Logger("index_uploader");

class IndexUploader {
  final Config config;
  final Storage storage;
  IndexUploader(this.config, this.storage);

  Future<Null> uploadIndexFiles() async {
    _logger.info("Uploading index files...");
    await storage.insertFile("404.html", new File(p.join(config.outputPath, "404.html")));
    await Future.wait(allIndexUrls.map((url) {
      return storage.insertFile(url, new File(p.join(config.outputPath, url)), maxAge: 60);
    }));
  }
}
