library crossdart.version;

import 'package:crossdart/src/util.dart';

class Version {
  String _versionString;

  Version(this._versionString);

  String toString() {
    return this._versionString;
  }

  String toPath() {
    return this._versionString.replaceAll("+", "-");
  }

  int get hashCode => hash([this._versionString]);

  bool operator ==(other) => other is Version
      && toString() == other.toString();
}