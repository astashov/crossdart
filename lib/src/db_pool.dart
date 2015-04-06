library crossdart.db_pool;

import 'package:sqljocky/sqljocky.dart';

ConnectionPool _dbPool;
ConnectionPool get dbPool {
  if (_dbPool == null) {
    _dbPool = new ConnectionPool(host: 'localhost', port: 3306, user: 'root', password: null, db: 'crossdart', max: 5);
  }
  return _dbPool;
}

deallocDbPool() {
  if (_dbPool != null) {
    _dbPool.close();
  }
  _dbPool = null;
}