#!/usr/bin/env dart

library migration;

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:crossdart/src/db_pool.dart';
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
  var config = new Config.buildFromFiles(dirroot: results[Config.DIR_ROOT], isDbUsed: true);

  await runMigrations(config);
}

Future<Null> runMigrations(Config config) async {
  await dbPool(config).prepareExecute("DROP TABLE IF EXISTS `packages_dependencies`", []);
  await dbPool(config).prepareExecute("DROP TABLE IF EXISTS `errors`", []);
  await dbPool(config).prepareExecute("DROP TABLE IF EXISTS `entities`", []);
  await dbPool(config).prepareExecute("DROP TABLE IF EXISTS `packages`", []);

  await dbPool(config).prepareExecute("""
    CREATE TABLE `packages` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
      `name` varchar(100) NOT NULL,
      `version` varchar(80) NOT NULL,
      `source_type` enum('GIT', 'HOSTED', 'SDK') NOT NULL,
      `description` text DEFAULT NULL,
      `readme` text DEFAULT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uniq` (`name`,`version`),
      KEY `created_at` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
  """, []);

  await dbPool(config).prepareExecute("""
    CREATE TABLE `entities` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
      `declaration_id` int(11) unsigned DEFAULT NULL,
      `type` ENUM('Reference', 'Declaration', 'Import', 'Token') NOT NULL,
      `kind` ENUM('CLASS', 'METHOD', 'LOCAL_VARIABLE', 'FUNCTION', 'PROPERTY_ACCESSOR', 'CONSTRUCTOR', 'FIELD', 'FUNCTION_TYPE_ALIAS', 'TOP_LEVEL_VARIABLE') DEFAULT NULL,
      `context_name` varchar(200) DEFAULT NULL,
      `name` varchar(200) DEFAULT NULL,
      `offset` int(11) unsigned DEFAULT NULL,
      `end` int(11) unsigned DEFAULT NULL,
      `line_number` int(11) unsigned DEFAULT NULL,
      `line_offset` int(11) unsigned DEFAULT NULL,
      `path` varchar(255) NOT NULL,
      `package_id` int(11) unsigned NOT NULL,
      `created_at` DATETIME NOT NULL,
      FOREIGN KEY foreign_package_id (`package_id`) REFERENCES `packages` (`id`) ON DELETE CASCADE,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uniq` (`package_id`,`type`,`path`,`offset`,`end`),
      KEY `created_at` (`created_at`),
      KEY `declaration_id` (`declaration_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
  """, []);

  await dbPool(config).prepareExecute("""
    CREATE TABLE `errors` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
      `package_name` varchar(100) NOT NULL,
      `package_version` varchar(80) NOT NULL,
      `error` text NOT NULL,
      `created_at` DATETIME NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uniq` (`package_name`, `package_version`),
      KEY `created_at` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
  """, []);

  await dbPool(config).prepareExecute("""
      CREATE TABLE `packages_dependencies` (
        `package_id` int(11) unsigned NOT NULL,
        `dependency_id` int(11) unsigned NOT NULL,
        FOREIGN KEY foreign_dependency_id (`dependency_id`) REFERENCES `packages` (`id`) ON DELETE CASCADE,
        FOREIGN KEY foreign_package_id (`package_id`) REFERENCES `packages` (`id`) ON DELETE CASCADE,
        UNIQUE KEY `uniq` (`package_id`,`dependency_id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    """, []);

  deallocDbPool();
}
