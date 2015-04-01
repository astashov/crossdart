library test;

import 'package:crossdart/src/parser.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/logging.dart';

void main(args) {
  config = new Config.fromArgs(args);
  initialize();
  parseFile("/Users/anton/.pub-cache/hosted/pub.dartlang.org/stagexl-0.9.2+1/lib/src/animation/tween.dart");
}