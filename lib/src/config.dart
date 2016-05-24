library crossdart.config;

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk_io.dart' show DirectoryBasedDartSdk;
import 'package:package_config/discovery.dart' as packages_discovery;
import 'dart:async';

enum OutputFormat { JSON, HTML }

class Config {
  final String dartSdk;
  final String input;
  final String output;
  final String hostedUrl;
  final String urlPathPrefix;
  final OutputFormat outputFormat;
  final String pubCachePath;

  static const String DART_SDK = "dart-sdk";
  static const String INPUT = "input";
  static const String OUTPUT = "output";
  static const String HOSTED_URL = "hosted-url";
  static const String URL_PREFIX_PATH = "url-prefix-path";
  static const String OUTPUT_FORMAT = "output-format";

  Config._({
    this.dartSdk,
    this.input,
    this.output,
    this.hostedUrl,
    this.urlPathPrefix,
    this.outputFormat,
    this.pubCachePath});

  static Future<Config> build({
      String dartSdk,
      String input,
      String output,
      String hostedUrl,
      String urlPathPrefix,
      OutputFormat outputFormat}) async {
    input ??= Directory.current.path;
    outputFormat ??= OutputFormat.HTML;
    String pubCachePath;
    if (input != dartSdk) {
      var packagesDiscovery = (await packages_discovery.loadPackagesFile(new Uri.file(path.join(input, ".packages")))).asMap();
      pubCachePath = new File.fromUri(packagesDiscovery.values.first).parent.parent.parent.parent.path;
    }
    return new Config._(
        dartSdk: dartSdk,
        input: input,
        output: output,
        hostedUrl: hostedUrl,
        urlPathPrefix: urlPathPrefix,
        outputFormat: outputFormat,
        pubCachePath: pubCachePath);
  }

  String get packagesPath {
    return path.join(input, ".packages");
  }

  String get urlPrefix => "${hostedUrl}/${urlPathPrefix}";

  String get hostedPackagesRoot {
    return path.join(pubCachePath, "hosted", "pub.dartlang.org");
  }

  String get gitPackagesRoot {
    return path.join(pubCachePath, "git");
  }

  String get sdkPackagesRoot {
    return path.join(pubCachePath, "sdk");
  }

  DartSdk get sdk {
    JavaSystemIO.setProperty("com.google.dart.sdk", dartSdk);
    return DirectoryBasedDartSdk.defaultSdk;
  }

  Config copy({
      String dartSdk,
      String input,
      String output,
      String hostedUrl,
      String urlPathPrefix,
      OutputFormat outputFormat}) {
    return new Config._(
        dartSdk: dartSdk ?? this.dartSdk,
        input: input ?? this.input,
        output: output ?? this.output,
        hostedUrl: hostedUrl ?? this.hostedUrl,
        urlPathPrefix: urlPathPrefix ?? this.urlPathPrefix,
        outputFormat: outputFormat ?? this.outputFormat);
  }
}
