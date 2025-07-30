CREATE TABLE `player_vehicles` (
	`id` INT(11) NOT NULL AUTO_INCREMENT,
	`license` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`citizenid` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`vehicle` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`hash` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`mods` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_bin',
	`plate` VARCHAR(15) NOT NULL COLLATE 'utf8mb4_unicode_ci',
	`fakeplate` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`garage` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`fuel` INT(11) NULL DEFAULT '100',
	`engine` FLOAT NULL DEFAULT '1000',
	`body` FLOAT NULL DEFAULT '1000',
	`state` INT(11) NULL DEFAULT '1',
	`depotprice` INT(11) NOT NULL DEFAULT '0',
	`last_pulled_by` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`last_pulled_at` TIMESTAMP NULL DEFAULT NULL,
	`total_distance` INT(11) NULL DEFAULT '0',
	`status` TEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`glovebox` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`trunk` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	PRIMARY KEY (`id`) USING BTREE,
	UNIQUE INDEX `plate` (`plate`) USING BTREE,
	INDEX `citizenid` (`citizenid`) USING BTREE,
	CONSTRAINT `player_vehicles_ibfk_1` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON UPDATE CASCADE ON DELETE CASCADE
)
COLLATE='utf8mb4_unicode_ci'
ENGINE=InnoDB
AUTO_INCREMENT=4
;
