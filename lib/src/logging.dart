library crossdart.logging;

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

void initialize() {
  String logFormatter(LogRecord record, {bool shouldConvertToPTZ: false}) {
    var timeString = new DateFormat("H:m:s.S").format(record.time);
    var name = record.loggerName.replaceAll(new RegExp(r"^crossdart\."), "");
    var message = "$timeString [${record.level.name}] ${name}: ${record.message}";
    return message;
  };

  Logger.root.onRecord.listen((record) {
    print(logFormatter(record));
  });

  Logger.root.level = Level.ALL;
}