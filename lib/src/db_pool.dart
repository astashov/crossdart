library crossdart.db_pool;

import 'package:sqljocky/sqljocky.dart';
import 'package:crossdart/src/config.dart';

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


void deallocDbPool() {
  if (_dbPool != null) {
    _dbPool.close();
  }
  _dbPool = null;
}