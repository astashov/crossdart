library crossdart.cleaners.package_cleaner;

import 'dart:io';

import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/package_info.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as yaml;
import 'package:crossdart/src/version.dart';

final _logger = new Logger("package_cleaner");

class PackageCleaner {
  final Config config;
  PackageCleaner(this.config);

  /// Deletes whole [config.outputPath]/[config.gcsPrefix] and installed packages in .pub-cache, which are not used by this app.
  ///
  /// Be careful when using that on your local machine - it will wipe out all the installed packages in .pub-cache!!!
  /// I decided to use this approach instead of deleting the packages after we generate them, because this is more
  /// reliable - in case of crashing, and after monit runs the app again, we won't have the leftovers after the previous
  /// run while generating the packages' docs
  void deleteSync({bool cleanPubCache: false}) {
    _logger.info("Cleaning old output${cleanPubCache ? ' and pub cache' : ''}");
    if (new Directory(p.join(config.outputPath, config.gcsPrefix)).existsSync()) {
      new Directory(p.join(config.outputPath, config.gcsPrefix)).deleteSync(recursive: true);
    }
    if (cleanPubCache) {
      var usedDirs = _usedByCrossdartGeneratorPackages.map((p) => p.dirname).toSet();
      new Directory(p.join(config.pubCachePath, "hosted", "pub.dartlang.org"))
          .listSync(recursive: false)
          .where((e) => e is Directory)
          .forEach((dir) {
        if (!usedDirs.contains(p.basename(dir.path))) {
          dir.deleteSync(recursive: true);
        }
      });
    }
  }

  Set<PackageInfo> _usedByCrossdartGeneratorPackagesMemoizer;
  Set<PackageInfo> get _usedByCrossdartGeneratorPackages {
    if (_usedByCrossdartGeneratorPackagesMemoizer == null) {
      Map<String, Map<String, String>> lockfile = yaml.loadYaml(
          new File(p.join(config.dirroot, "pubspec.lock")).readAsStringSync())["packages"];
      var packages = new Set();
      lockfile.forEach((String key, Map<String, String> values) {
        packages.add(new PackageInfo(key, new Version(values["version"])));
      });
      _usedByCrossdartGeneratorPackagesMemoizer = packages;
    }
    return _usedByCrossdartGeneratorPackagesMemoizer;
  }
}
