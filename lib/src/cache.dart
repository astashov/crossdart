library crossdart.cache;

import 'dart:io';
import 'dart:collection';

class Cache {
  Map<String, String> _fileContents = {};
  Map<String, SplayTreeMap<int, int>> _lineNumbers = {};


  String fileContents(String file) {
    if (_fileContents[file] == null) {
      _fileContents[file] = new File(file).readAsStringSync();
    }
    return _fileContents[file];
  }

  int lineNumber(String file, int offset) {
    if (offset == 0) {
      return 0;
    } else {
      if (_lineNumbers[file] == null) {
        _lineNumbers[file] = _createLineNumbersMap(fileContents(file));
      }
      var lastKey = _lineNumbers[file].lastKeyBefore(offset);
      return _lineNumbers[file][lastKey];
    }
  }

  int numberOfLines(String file) {
    if (_lineNumbers[file] == null) {
      _lineNumbers[file] = _createLineNumbersMap(fileContents(file));
    }
    return _lineNumbers[file][_lineNumbers[file].lastKey()];
  }

  int lineOffset(String file, int offset) {
    if (offset == 0) {
      return 0;
    } else {
      if (_lineNumbers[file] == null) {
        _lineNumbers[file] = _createLineNumbersMap(fileContents(file));
      }
      var lastKey = _lineNumbers[file].lastKeyBefore(offset);
      var result = offset - lastKey;
      if (lineNumber(file, offset) > 0) {
        result -= 1;
      }
      return result;
    }
  }

  SplayTreeMap<int, int> _createLineNumbersMap(String contents) {
    var newlineChar = getNewlineChar(contents);
    var offset = 0;
    var lineNumber = 0;
    var result = new SplayTreeMap();

    if (contents.length > 0) {
      do {
        result[offset] = lineNumber;
        offset = contents.indexOf(newlineChar, offset + 1);
        lineNumber += 1;
      } while (offset != -1);
    } else {
      result[offset] = lineNumber;
    }

    return result;
  }

  String getNewlineChar(String contents) {
    if (contents.contains("\r\n")) {
      return "\r\n";
    } else if (contents.contains("\r")) {
      return "\r";
    } else {
      return "\n";
    }
  }

}

var cache = new Cache();