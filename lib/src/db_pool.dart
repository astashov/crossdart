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

Future<Results> query(Config config, String sql, {int retries: 3, QueriableConnection conn: null}) async {
  return retriable(config, 3, conn, (c) => c.query(sql));
}

Future<Results> prepare(Config config, String sql, {int retries: 3, QueriableConnection conn: null}) async {
  return retriable(config, 3, conn, (c) => c.prepare(sql));
}

Future<Results> prepareExecute(Config config, String sql, List parameters, {int retries: 3, QueriableConnection conn: null}) async {
  return retriable(config, 3, conn, (c) => c.prepareExecute(sql, parameters));
}


Future<Results> retriable(Config config, int retries, QueriableConnection conn, Future<Results> body(QueriableConnection conn)) async {
  if (conn == null) {
    conn = dbPool(config);
  }
  try {
    return await body(conn);
  } on SocketException catch(exception, stackTrace) {
    _logger.warning("Got exception - $exception, retries left - $retries, retrying...");
    if (retries > 0) {
      _dbPool == null;
      return new Future.delayed(new Duration(seconds: 5), () {
        return retriable(config, body, retries: retries - 1, conn: conn);
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