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
      `package_id` int(11) unsigned NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uniq` (`type`,`offset`,`end`,`file`,`package_id`),
      KEY `type` (`type`),
      KEY `package_id` (`package_id`),
      KEY `file` (`file`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
  """, []);

  await dbPool.prepareExecute("DROP TABLE IF EXISTS `errors`", []);
  await dbPool.prepareExecute("""
    CREATE TABLE `errors` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
      `package_id` int(11) unsigned NOT NULL,
      `error` text NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uniq` (`package_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
  """, []);

  await dbPool.prepareExecute("DROP TABLE IF EXISTS `packages`", []);
  await dbPool.prepareExecute("""
    CREATE TABLE `packages` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
      `name` varchar(255) NOT NULL,
      `version` varchar(255) NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uniq` (`name`,`version`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
  """, []);

  await dbPool.prepareExecute("DROP TABLE IF EXISTS `packages_dependencies`", []);
  await dbPool.prepareExecute("""
      CREATE TABLE `packages_dependencies` (
        `package_id` int(11) unsigned NOT NULL,
        `dependency_id` int(11) unsigned NOT NULL,
        UNIQUE KEY `uniq` (`package_id`,`dependency_id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    """, []);

  dbPool.close();
}