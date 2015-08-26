library crossdart.url;

import 'package:crossdart/src/package_info.dart';
import 'package:path/path.dart';

const String PATH_PREFIX = "p";

String packageIndexUrl(PackageInfo packageInfo, {bool shouldAddVersion: true}) {
  var url = "/" + join(PATH_PREFIX, packageInfo.name, "index.html");
  if (shouldAddVersion) {
    url += "#${packageInfo.version}";
  }
  return url;
}
