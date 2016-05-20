library crossdart.util.isolate;

import 'dart:async';
import 'dart:isolate';
import 'package:logging/logging.dart';
import 'package:crossdart/src/isolate_events.dart';

Future parallelRunner(
    Iterable<Iterable<Object>> collection,
    Future runnable(SendPort sender),
    Iterable payload(int index, int tupleIndex, Object item), {
    Logger logger,
    Future onError(exception, stackTrace, Object item),
    void onMessage(Isolate isolate, IsolateEvent msg, Completer completer, List<Timer> timer)}) async {
  var index = 0;
  for (Iterable<Object> subcollection in collection) {
    var tupleIndex = 0;
    var futures = subcollection.map((Object item) {
      List<Timer> timer = [];
      Iterable data = payload(index, tupleIndex, item);
      tupleIndex += 1;
      index += 1;
      return runIsolate(runnable, data, (isolate, msg, completer) {
        if (logger != null) {
          logger.fine("Received a message - ${msg}");
        }
        if (msg == IsolateEvent.FINISH) {
          isolate.kill(priority: Isolate.IMMEDIATE);
          completer.complete(msg);
        } else if (msg == IsolateEvent.ERROR) {
          isolate.kill(priority: Isolate.IMMEDIATE);
          completer.completeError("error");
        }
        if (onMessage != null) {
          onMessage(isolate, msg, completer, timer);
        }
      }).catchError((exception, stackTrace) {
        if (onError != null) {
          return onError(exception, stackTrace, item);
        }
      });
    });
    await Future.wait(futures);
  };
}

Future runIsolate(Function isolateFunction, input, void callback(Isolate isolate, message, Completer completer)) {
  var receivePort = new ReceivePort();
  var completer = new Completer();

  print("About to spawn");
  Isolate.spawn(isolateFunction, receivePort.sendPort).then((isolate) {
    print("Spawned!");
    receivePort.listen((msg) {
      if (msg is SendPort) {
        msg.send(input);
      } else {
        callback(isolate, msg, completer);
      }
    });
  });

  return completer.future.then((v) {
    receivePort.close();
    return v;
  });
}

void runInIsolate(SendPort sender, void callback(data)) {
  print("Running");
  var receivePort = new ReceivePort();
  sender.send(receivePort.sendPort);
  receivePort.listen((data) {
    callback(data);
  });
}

