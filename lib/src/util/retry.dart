library crossdart.utils.retry;

import 'dart:async';
import 'package:logging/logging.dart';

final Logger _logger = new Logger("retry");

const _defaultDurations = const [
  const Duration(seconds: 3),
  const Duration(seconds: 5),
  const Duration(seconds: 15)
];

/// Utility function, which will retry the given lambda [body] several times, with specified durations, and will
/// rethrow after the retries are out.
///
/// Useful for wrapping any unreliable parts of code, like network access.
Future<dynamic> retry(body(),
    {int number: 3,
    Iterable<Duration> durations: _defaultDurations,
    bool fromRetry: false}) async {
  try {
    if (fromRetry) {
      _logger.info("Retrying with retries left: $number");
    }
    var result = await body();
    return result;
  } catch (error, _) {
    if (number > 0) {
      var duration = durations.first;
      var newDurations = new List.from(durations);
      if (newDurations.length > 1) {
        newDurations.removeAt(0);
      }
      var newNumber = number - 1;
      _logger.warning(
          "Got an exception: $error, will retry, retries left: $newNumber, waiting for ${duration.inSeconds}s");
      return new Future.delayed(
          duration,
          () => retry(body,
          number: newNumber, durations: newDurations, fromRetry: true));
    } else {
      _logger
          .warning("Got an exception: $error, out of retries, rethrowing...");
      rethrow;
    }
  }
}
