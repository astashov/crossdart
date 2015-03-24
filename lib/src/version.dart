library crossdart.version;

import 'package:crossdart/src/util.dart';

class Version {
  int _major;
  int get major => _major;

  int _minor;
  int get minor => _minor;

  int _patch;
  int get patch => _patch;

  int _addition;
  int get addition => _addition;

  String _versionString;

  Version(this._major, this._minor, this._patch, [this._addition]);

  Version.fromString(String str) {
    _versionString = str;
    var match = str.split(".");
    _major = int.parse(match[0]);
    _minor = int.parse(match[1]);
    var patchAndAddition = match[2].split("+");
    _patch = int.parse(patchAndAddition[0]);
    if (patchAndAddition.length > 1) {
      _addition = int.parse(patchAndAddition[1]);
    }
  }

  String toString() {
    if (_versionString != null) {
      return _versionString;
    } else {
      var string = "${major}.${minor}.${patch}";
      if (addition != null) {
        string += "+${addition}";
      }
      return string;
    }
  }

  String toPath() {
    var string = "${major}.${minor}.${patch}";
    if (addition != null) {
      string += "-${addition}";
    }
    return string;
  }

  int get hashCode => hash([major, minor, patch, addition]);

  bool operator ==(other) => other is Version
      && major == other.major
      && minor == other.minor
      && patch == other.patch
      && addition == other.addition;
}