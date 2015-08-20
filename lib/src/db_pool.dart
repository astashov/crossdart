library crossdart.db_pool;

import 'package:sqljocky/sqljocky.dart';
import 'package:crossdart/src/config.dart';
import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';

Logger _logger = new Logger("db_pool");

ConnectionPool _dbPool;
ConnectionPool dbPool(Config config) {
  if (_dbPool == null) {
    if (config.isDbUsed) {
      var login = config.dbLogin != null ? config.dbLogin : "root";
      var password = config.dbPassword != null ? config.dbPassword : "";
      var host = config.dbHost != null ? config.dbHost : "localhost";
      var port = config.dbPort != null ? config.dbPort : "3306";
      var name = config.dbName != null ? config.dbName : "crossdart";
      _dbPool = new ConnectionPool(
          host: host,
          port: int.parse(port),
          user: login,
          password: (password == '' ? null : password),
          db: name,
          max: 5);
    } else {
      throw "This application should not use the database";
    }
  }
  return _dbPool;
}

Future<Results> query(Config config, String sql, {int retries: 3}) async {
  return retriable(config, 3, (c) => c.query(sql));
}

Future<Results> prepare(Config config, String sql, {int retries: 3}) async {
  return retriable(config, 3, (c) => c.prepare(sql));
}

Future<Results> prepareExecute(Config config, String sql, List parameters, {int retries: 3}) async {
  return retriable(config, 3, (c) => c.prepareExecute(sql, parameters));
}


Future<Results> retriable(Config config, int retries, Future<Results> body(QueriableConnection conn)) async {
  try {
    return await body(dbPool(config));
  } on SocketException catch(exception, _) {
    _logger.warning("Got exception - $exception, retries left - $retries, retrying...");
    if (retries > 0) {
      _dbPool = null;
      return new Future.delayed(new Duration(seconds: 5), () {
        return retriable(config, retries - 1, body);
      });
    } else {
      rethrow;
    }
  }
}

void deallocDbPool() {
  if (_dbPool != null) {
    _dbPool.close();
  }
  _dbPool = null;
}