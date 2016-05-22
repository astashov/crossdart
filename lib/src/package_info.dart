library crossdart.package_info;

import 'dart:io';
import 'dart:convert';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/util.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

enum PackageSource { GIT, HOSTED, SDK }
final Map<String, PackageSource> packageSourceMapping = {"GIT": PackageSource.GIT, "HOSTED": PackageSource.HOSTED, "SDK": PackageSource.SDK};

class PackageInfo implements Comparable<PackageInfo> {
  final String name;
  final Version version;
  final int id;
  final PackageSource source;
  final DateTime createdAt;

  PackageInfo(this.name, this.version, {this.id, this.source, this.createdAt});

  int get hashCode => hash([name, version]);

  bool operator ==(other) => other is PackageInfo
      && name == other.name
      && version == other.version;

  int compareTo(PackageInfo other) {
    if (name == other.name) {
      return version.compareTo(other.version);
    } else {
      return name.compareTo(other.name);
    }
  }

  String absolutePath(Config config) {
    return p.join(config.outputPath, config.gcsPrefix, name, version.toString());
  }

  String logPath(Config config) {
    return p.join(config.outputPath, config.gcsPrefix, name, version.toString(), "log.txt");
  }

  String logUrl(Config config) {
    return p.join(config.gcsPrefix, name, version.toString(), "log.txt");
  }

  String urlRoot(Config config) {
    return p.join(config.gcsPrefix, name, version.toString());
  }

  Iterable<String> generatedPaths(Config config) {
    return new Directory(absolutePath(config))
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

  String getDirectoryInPubCache(Config config) {
    if (isSdk) {
      if (version == config.sdk.sdkVersion) {
        return config.sdkPath;
      } else {
        return p.join(config.sdkPackagesRoot, dirname);
      }
    } else {
      Directory directory = new Directory(config.hostedPackagesRoot).listSync().firstWhere((entity) {
        return p.basename(entity.path).toLowerCase() == "${name}-${version}".toLowerCase()
            || p.basename(entity.path).replaceAll("+", "-").toLowerCase() == "${name}-${version}".toLowerCase();
      }, orElse: () => null);
      if (directory == null) {
         directory = new Directory(config.gitPackagesRoot).listSync().firstWhere((entity) {
          return p.basename(entity.path).toLowerCase() == "${name}-${version}".toLowerCase()
             || p.basename(entity.path).replaceAll("+", "-").toLowerCase() == "${name}-${version}".toLowerCase();
        }, orElse: () => null);
      }
      return directory == null ? null : directory.resolveSymbolicLinksSync();
    }
  }


  Map<String, String> toMap() {
    return {"name": name, "version": version.toString(), "id": id};
  }

  String toJson() {
    return JSON.encode(toMap());
  }

  factory PackageInfo.fromJson(String json) {
    final map = JSON.decode(json);
    return new PackageInfo(map["name"], new Version.parse(map["version"]));
  }

  factory PackageInfo.buildSdk(Config config) {
    return new PackageInfo("sdk", new Version.parse(config.sdk.sdkVersion));
  }
}