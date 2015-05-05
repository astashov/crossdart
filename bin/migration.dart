#!/usr/bin/env dart

library migration;

import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:crossdart/src/config.dart';
import 'package:crossdart/src/args.dart';

Logger _logger = new Logger("migration");

main(args) async {
  Logger.root.level = Level.FINE;
  var migrationArgs = new MigrationArgs(args);
  if (!migrationArgs.runChecks()) {
    return;
  }

  var results = migrationArgs.results;
  var config = new Config(
      dbLogin: results[Config.DB_LOGIN],
      dbPassword: results[Config.DB_PASSWORD],
      dbHost: results[Config.DB_HOST],
      dbPort: results[Config.DB_PORT],
      dbName: results[Config.DB_NAME],
      isDbUsed: true);

  await runMigrations(config);
}

Future<Null> runMigrations(Config config) async {
  await config.dbPool.prepareExecute("DROP TABLE IF EXISTS `packages_dependencies`", []);
  await config.dbPool.prepareExecute("DROP TABLE IF EXISTS `errors`", []);
  await config.dbPool.prepareExecute("DROP TABLE IF EXISTS `entities`", []);
  await config.dbPool.prepareExecute("DROP TABLE IF EXISTS `packages`", []);

  await config.dbPool.prepareExecute("""
    CREATE TABLE `packages` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
      `name` varchar(255) NOT NULL,
      `version` varchar(255) NOT NULL,
      `source_type` tinyint NOT NULL,
      `description` text,
      `readme` text,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uniq` (`name`,`version`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
  """, []);

  await config.dbPool.prepareExecute("""
    CREATE TABLE `entities` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
      `declaration_id` int(11) unsigned DEFAULT NULL,
      `type` smallint(4) NOT NULL,
      `context_name` varchar(255) DEFAULT NULL,
      `name` varchar(255) DEFAULT NULL,
      `offset` int(11) unsigned DEFAULT NULL,
      `end` int(11) unsigned DEFAULT NULL,
      `path` varchar(255) NOT NULL,
      `package_id` int(11) unsigned NOT NULL,
      FOREIGN KEY foreign_package_id (`package_id`) REFERENCES `packages` (`id`) ON DELETE CASCADE,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uniq` (`type`,`offset`,`end`,`path`,`package_id`),
      KEY `type` (`type`),
      KEY `package_id` (`package_id`),
      KEY `path` (`path`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
  """, []);

  await config.dbPool.prepareExecute("""
    CREATE TABLE `errors` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
      `package_name` varchar(255) NOT NULL,
      `package_version` varchar(255) NOT NULL,
      `error` text NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uniq` (`package_name`, `package_version`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
  """, []);

  await config.dbPool.prepareExecute("""
      CREATE TABLE `packages_dependencies` (
        `package_id` int(11) unsigned NOT NULL,
        `dependency_id` int(11) unsigned NOT NULL,
        FOREIGN KEY foreign_dependency_id (`dependency_id`) REFERENCES `packages` (`id`) ON DELETE CASCADE,
        FOREIGN KEY foreign_package_id (`package_id`) REFERENCES `packages` (`id`) ON DELETE CASCADE,
        UNIQUE KEY `uniq` (`package_id`,`dependency_id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    """, []);

  config.deallocDbPool();
}
