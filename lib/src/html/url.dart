library crossdart.url;

import 'package:crossdart/src/package_info.dart';
import 'package:path/path.dart';

const String PATH_PREFIX = "p";

String packageIndexUrl(PackageInfo packageInfo, {bool shouldAddVersion: true}) {
  String name = packageInfo.name;
  if (shouldAddVersion) {
    name += "#${packageInfo.version}";
  }
  return "/" + join(PATH_PREFIX, name);
}
