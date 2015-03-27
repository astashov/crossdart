#!/usr/bin/env dart

import 'package:logging/logging.dart';
import 'package:crossdart/src/db_pool.dart';

Logger _logger = new Logger("migration");

main(args) async {
  Logger.root.level = Level.FINE;
  await dbPool.prepareExecute("DROP TABLE IF EXISTS `entities`", []);
  await dbPool.prepareExecute("""
    CREATE TABLE `entities` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
      `declaration_id` int(11) unsigned DEFAULT NULL,
      `type` smallint(4) NOT NULL,
      `name` varchar(255) DEFAULT NULL,
      `offset` int(11) unsigned DEFAULT NULL,
      `end` int(11) unsigned DEFAULT NULL,
      `file` varchar(255) NOT NULL,
      `package_name` varchar(255) NOT NULL,
      `package_version` varchar(255) NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uniq` (`type`,`offset`,`end`,`file`,`package_name`,`package_version`),
      KEY `type` (`type`),
      KEY `package` (`package_name`,`package_version`),
      KEY `file` (`file`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
  """, []);

  await dbPool.prepareExecute("DROP TABLE IF EXISTS `errors`", []);
  await dbPool.prepareExecute("""
    CREATE TABLE `errors` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
      `package_name` varchar(255) NOT NULL,
      `package_version` varchar(255) NOT NULL,
      `error` text NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uniq` (`package_name`,`package_version`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
  """, []);

  dbPool.close();
}