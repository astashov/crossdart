library crossdart.package_info;

import 'dart:io';
import 'dart:convert';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/util.dart';
import 'package:path/path.dart' as p;

class PackageInfo {
  final String name;
  final Version version;

  PackageInfo(this.name, this.version);

  int get hashCode => hash([name, version]);

  bool operator ==(other) => other is PackageInfo
      && name == other.name
      && version == other.version;

  Iterable<String> generatedPaths(Config config) {
    var absolutePath = p.join(config.outputPath, name, version.toPath());
    return new Directory(absolutePath)
        .listSync(recursive: true)
        .where((f) => f is File && f.path.endsWith(".html"))
        .map((s) => s.path.replaceAll(absolutePath, "").replaceAll(new RegExp(r".html$"), ""));
  }

  String toString() {
    return "<PackageInfo ${toMap()}>";
  }

  Map<String, String> toMap() {
    return {"name": name, "version": version.toString()};
  }

  factory PackageInfo.fromJson(String json) {
    final map = JSON.decode(json);
    return new PackageInfo(map["name"], new Version(map["version"]));
  }

  factory PackageInfo.buildSdk(Config config) {
    return new PackageInfo("sdk", new Version(config.sdk.sdkVersion));
  }
}