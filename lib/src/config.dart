library crossdart.config;

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:crossdart/src/package_info.dart';
import 'package:crossdart/src/version.dart';
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk_io.dart' show DirectoryBasedDartSdk;

class Config {
  final String sdkPath;
  final String installPath;
  final String htmlPath;
  final String templatesPath;

  Config(this.sdkPath, this.installPath, this.htmlPath, this.templatesPath);

  Config.fromArgs(List args) :
    this.sdkPath = args[0],
    this.installPath = args[1],
    this.htmlPath = args[2],
    this.templatesPath = args[3];

  String __packagesRoot;
  String get _packagesRoot {
    if (__packagesRoot == null) {
      var lib = (new Directory(packagesPath).listSync().first).resolveSymbolicLinksSync();
      __packagesRoot = path.dirname(path.dirname(lib));
      if (!__packagesRoot.endsWith("/")) {
        __packagesRoot += "/";
      }
    }
    return __packagesRoot;
  }

  String get hostedPackagesRoot {
    return _packagesRoot.replaceFirst("/git/", "/hosted/pub.dartlang.org/").replaceFirst(new RegExp(r"/$"), "");
  }

  String get gitPackagesRoot {
      return _packagesRoot.replaceFirst("/hosted/pub.dartlang.org/", "/git/").replaceFirst(new RegExp(r"/$"), "");
    }

  String get packagesPath => path.join(installPath, "packages");

  DartSdk get sdk {
    JavaSystemIO.setProperty("com.google.dart.sdk", sdkPath);
    return DirectoryBasedDartSdk.defaultSdk;
  }

  Iterable<Iterable<PackageInfo>> get generatedPackageInfos {
    return new Directory(htmlPath).listSync().where((f) => f is Directory).map((Directory dir) {
      var versions = dir.listSync().where((f) => f is Directory).map((d) => path.basename(d.path)).toList();
      versions.sort();
      return versions.map((version) => new PackageInfo(path.basename(dir.path), new Version(version)));
    });
  }

}