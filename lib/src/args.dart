library crossdart.args;

import 'package:args/args.dart';
import 'package:crossdart/src/config.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

abstract class Args {
  final List<String> _args;
  List<String> get requiredKeys;
  String get description;

  final ArgParser parser;

  Args(this._args) :
      this.parser = new ArgParser() {
    parser.addOption(Config.DIR_ROOT, help: "Current directory", defaultsTo: Directory.current.path);
    parser.addFlag("help", help: "Show help.", negatable: false);
  }

  Map<String, Object> _getResults() {
    var argsResults = parser.parse(_args);
    return argsResults.options.fold({}, (memo, option) {
      memo[option] = argsResults[option];
      return memo;
    });
  }

  Map<String, Object> _results;
  Map<String, Object> get results {
    if (_results == null) {
      _results = _getResults();
    }
    return _results;
  }

  bool get shouldShowHelp {
    return results["help"] == true;
  }

  Iterable<String> get missingRequiredKeys {
    return requiredKeys.where((k) => results[k] == null);
  }

  void showHelp([String error]) {
    print("Crossdart - Dart hyperlinked source code generator.\n");
    print("$description\n");
    if (error != null) {
      print("${error}\n");
    }
    print("Available options:");
    print(parser.usage);
  }

  void addSdkArgsOptions() {
    parser.addOption(Config.SDK_PATH, help: "Path where Dart SDK at. Required.");
  }

  bool runChecks() {
    if (shouldShowHelp) {
      showHelp();
      return false;
    } else if (missingRequiredKeys.isNotEmpty) {
      showHelp("Missing required keys: ${missingRequiredKeys.join(", ")}.");
      return false;
    } else {
      return true;
    }
  }
}

class MigrationArgs extends Args {
  List<String> get requiredKeys => [];
  String get description => "migration.dart wipes out all the data from the database and recreates its structure.";

  MigrationArgs(List<String> args) : super(args);
}

class ParsePackagesArgs extends Args {
  List<String> get requiredKeys => [];
  String get description {
    return "parse_packages.dart analyzes all the packages from the pub " +
        "and stores the analyze information in the database.";
  }

  ParsePackagesArgs(List<String> args) : super(args) {
    addSdkArgsOptions();
    parser.addOption(Config.PART, help: "What part of total results will be handled. Format - n/m. E.g. 1/4 means it will handle the first quarter of all the packages. Default is 1/1.", defaultsTo: "1/1");
  }
}

class InstallPackagesArgs extends Args {
  List<String> get requiredKeys => [];
  String get description {
    return "install_packages.dart installs all the analyzed packages.";
  }

  InstallPackagesArgs(List<String> args) : super(args) {
    addSdkArgsOptions();
  }
}

class CrossdartArgs extends Args {
  List<String> get requiredKeys => [Config.SDK_PATH, Config.PROJECT_PATH];
  String get description {
    return "crossdart.dart analyzes all the files of the given project, " +
        "and stores the analyze information in the crossdart.json file.";
  }

  CrossdartArgs(List<String> args) : super(args) {
    addSdkArgsOptions();
    parser.addOption(Config.PROJECT_PATH, help: "Path where the project is located at. Required.");
  }

  Map<String, Object> _getResults() {
    var theResults = super._getResults();
    if (theResults[Config.PROJECT_PATH] != null) {
      var resolvedSymlink = new Directory(p.join(theResults[Config.PROJECT_PATH], "packages")).listSync().first.resolveSymbolicLinksSync();
      theResults[Config.PUB_CACHE_PATH] = p.dirname(p.dirname(p.dirname(p.dirname(resolvedSymlink))));

      if (theResults[Config.OUTPUT_PATH] == null) {
        theResults[Config.OUTPUT_PATH] = theResults[Config.PROJECT_PATH];
      }
    }
    return theResults;
  }
}

class GeneratePackagesHtmlArgs extends Args {
  List<String> get requiredKeys => [];
  String get description {
    return "generate_packages_html.dart reads the analysis data from the database, " +
        "and generates HTML files with the hyperlinked source code.";
  }

  GeneratePackagesHtmlArgs(List<String> args) : super(args) {
    addSdkArgsOptions();
  }
}

class UpdatedFilesListArgs extends Args {
  List<String> get requiredKeys => [];
  String get description => "updated_files_list.dart returns a list of the updated HTML files needed to upload to S3.";

  UpdatedFilesListArgs(List<String> args) : super(args);
}