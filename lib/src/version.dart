library crossdart.version;

import 'package:crossdart/src/util.dart';

final RegExp _versionRegexp = new RegExp(r"^(\d+)\.(\d+)\.(\d+)(.*)$");

class Version implements Comparable {
  String _versionString;

  Version(this._versionString);

  String toString() {
    return this._versionString;
  }

  String toPath() {
    return this._versionString.replaceAll("+", "-");
  }

  bool get doesFollowSemanticVersioning => _versionRegexp.hasMatch(toString());

  int get hashCode => hash([this._versionString]);

  bool operator ==(other) => other is Version
      && toString() == other.toString();

  int compareTo(Version other) {
    if (doesFollowSemanticVersioning && other.doesFollowSemanticVersioning) {
      return new _ParsedVersion.fromString(toString()).compareTo(new _ParsedVersion.fromString(other.toString()));
    } else {
      return toString().compareTo(other.toString());
    }
  }
}

class _ParsedVersion implements Comparable {
  final int major;
  final int minor;
  final int patch;
  final String additional;

  _ParsedVersion(this.major, this.minor, this.patch, this.additional);

  factory _ParsedVersion.fromString(String input) {
    var match = _versionRegexp.firstMatch(input);
    var major = int.parse(match.group(1));
    var minor = int.parse(match.group(2));
    var patch = int.parse(match.group(3));
    var additional = match.group(4).toString();
    return new _ParsedVersion(major, minor, patch, additional);
  }

  int compareTo(_ParsedVersion other) {
    var majorMatch = major.compareTo(other.major);
    if (majorMatch != 0) {
      return majorMatch;
    } else {
      var minorMatch = minor.compareTo(other.minor);
      if (minorMatch != 0) {
        return minorMatch;
      } else {
        var patchMatch = patch.compareTo(other.patch);
        if (patchMatch != 0) {
          return patchMatch;
        } else {
          return additional.compareTo(other.additional);
        }
      }
    }
  }

}