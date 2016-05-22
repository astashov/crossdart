library crossdart.logging;

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

List<String> logs = [];

void initialize([int index]) {
  String logFormatter(LogRecord record, {bool shouldConvertToPTZ: false}) {
    var timeString = new DateFormat("H:m:s.S").format(record.time);
    String message = "";
    var name = record.loggerName.replaceAll(new RegExp(r"^crossdart\."), "");
    if (index != null) {
      message += "$index - ";
    }
    message += "$timeString [${record.level.name}] ${name}: ${record.message}";
    if (record.error != null) {
      message += "\n${record.error}\n${record.stackTrace}";
    }
    return message;
  };

  Logger.root.onRecord.listen((record) {
    if (record.loggerName != "ConnectionPool") {
      var message = logFormatter(record);
      logs.add(message);
      print(message);
    }
  });

  Logger.root.level = Level.INFO;
}

void reset() {
  logs = [];
}
