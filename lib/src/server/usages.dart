library crossdart.server.usages;

import 'package:crossdart/src/package_info.dart';

class Usages {
  final int _declarationId;
  Usages(this._declarationId);

  Iterable<Usage> find() {

  }
}

class Usage {
  PackageInfo packageInfo;
  String path;
  int lineNumber;

  Usage(this.packageInfo, this.path, this.lineNumber);

  Usage.fromDatabase(int declarationId) {

  }
}
