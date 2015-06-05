library crossdart.package_info;

import 'dart:io';
import 'dart:convert';
import 'package:crossdart/src/version.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/util.dart';
import 'package:crossdart/src/html/url.dart';
import 'package:path/path.dart' as p;

enum PackageSource { GIT, HOSTED, SDK }
final Map<PackageSource, int> packageSourceIds = {PackageSource.GIT: 1, PackageSource.HOSTED: 2, PackageSource.SDK: 3};

class PackageInfo {
  final String name;
  final Version version;
  final int id;
  final PackageSource source;

  PackageInfo(this.name, this.version, {this.id, this.source});

  int get hashCode => hash([name, version]);

  bool operator ==(other) => other is PackageInfo
      && name == other.name
      && version == other.version;

  Iterable<String> generatedPaths(Config config) {
    var absolutePath = p.join(config.outputPath, PATH_PREFIX, name, version.toPath());
    return new Directory(absolutePath)
        .listSync(recursive: true)
        .where((f) => f is File && f.path.endsWith(".html"))
        .map((s) => s.path.replaceAll(config.outputPath, "").replaceAll(new RegExp(r".html$"), ""));
  }

  String get dirname => "${name}-${version}";

  String toString() {
    return "<PackageInfo ${toMap()}>";
  }

  bool get isSdk {
    return name == "sdk";
  }

  PackageInfo update({String name, Version version, int id, PackageSource source}) {
    return new PackageInfo(
        name == null ? this.name : name,
        version == null ? this.version : version,
        id: id == null ? this.id : id,
        source: source == null ? this.source : source);
  }

  Map<String, String> toMap() {
    return {"name": name, "version": version.toString(), "id": id};
  }

  String toJson() {
    return JSON.encode(toMap());
  }

  factory PackageInfo.fromJson(String json) {
    final map = JSON.decode(json);
    return new PackageInfo(map["name"], new Version(map["version"]));
  }

  factory PackageInfo.buildSdk(Config config) {
    return new PackageInfo("sdk", new Version(config.sdk.sdkVersion));
  }
}