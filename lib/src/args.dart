library crossdart.args;

import 'package:args/args.dart';
import 'package:crossdart/src/config.dart';

abstract class Args {
  final List<String> _args;
  List<String> get requiredKeys;
  String get description;

  final ArgParser parser;

  Args(this._args) :
      this.parser = new ArgParser() {
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

class CrossdartArgs extends Args {
  List<String> get requiredKeys => [];
  String get description {
    return "crossdart.dart analyzes all the files of the given project, " +
        "and stores the analyze information in the crossdart.json file.";
  }

  CrossdartArgs(List<String> args) : super(args) {
    parser.addOption(Config.INPUT, help: "Path where the project is located at. Required.");
    parser.addOption(Config.OUTPUT, help: "Output path");
    parser.addOption(Config.HOSTED_URL, help: "Output format");
    parser.addOption(Config.DART_SDK, help: "Output format");
    parser.addOption(Config.OUTPUT_FORMAT, help: "Output format");
    parser.addOption(Config.URL_PATH_PREFIX);
  }
}
