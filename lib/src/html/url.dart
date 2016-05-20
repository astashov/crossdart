library crossdart.url;

import 'package:crossdart/src/package_info.dart';
import 'package:path/path.dart';
import 'package:crossdart/src/config.dart';

String packageIndexUrl(Config config, PackageInfo packageInfo, {bool shouldAddVersion: true}) {
  var url = "/" + join(config.gcsPrefix, packageInfo.name, "index.html");
  if (shouldAddVersion) {
    url += "#${packageInfo.version}";
  }
  return url;
}
