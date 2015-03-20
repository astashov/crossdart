library crossdart.cache;

import 'dart:io';

class Cache {
  Map<String, String> _fileContents = {};

  String fileContents(String file) {
    if (_fileContents[file] == null) {
      _fileContents[file] = new File(file).readAsStringSync();
    }
    return _fileContents[file];
  }
}

var cache = new Cache();