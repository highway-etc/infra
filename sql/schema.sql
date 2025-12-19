-- 生产版：16 分片库，表内按月分区，MyCat 按 station_id 一致性哈希路由
USE mysql;
DELIMITER // DROP PROCEDURE IF EXISTS create_shards // CREATE PROCEDURE create_shards() BEGIN
DECLARE i INT DEFAULT 0;
-- 创建 16 个物理库
WHILE i < 16 DO
SET @db = CONCAT('etc_', LPAD(i, 2, '0'));
SET @create_db = CONCAT(
        'CREATE DATABASE IF NOT EXISTS ',
        @db,
        ' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
    );
PREPARE stmt
FROM @create_db;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET i = i + 1;
END WHILE;
-- 账号授权
CREATE USER IF NOT EXISTS 'etcuser' @'%' IDENTIFIED BY 'etcpass';
SET i = 0;
WHILE i < 16 DO
SET @db = CONCAT('etc_', LPAD(i, 2, '0'));
SET @grant_sql = CONCAT(
        'GRANT ALL PRIVILEGES ON ',
        @db,
        '.* TO "etcuser"@"%"'
    );
PREPARE stmt
FROM @grant_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET i = i + 1;
END WHILE;
FLUSH PRIVILEGES;
-- 分区定义：覆盖 2024-2026，后续可追加分区，pmax 兜底
SET @traffic_partitions = 'PARTITION BY RANGE (TO_DAYS(gcsj)) (
        PARTITION p202401 VALUES LESS THAN (TO_DAYS("2024-02-01")),
        PARTITION p202402 VALUES LESS THAN (TO_DAYS("2024-03-01")),
        PARTITION p202403 VALUES LESS THAN (TO_DAYS("2024-04-01")),
        PARTITION p202404 VALUES LESS THAN (TO_DAYS("2024-05-01")),
        PARTITION p202405 VALUES LESS THAN (TO_DAYS("2024-06-01")),
        PARTITION p202406 VALUES LESS THAN (TO_DAYS("2024-07-01")),
        PARTITION p202407 VALUES LESS THAN (TO_DAYS("2024-08-01")),
        PARTITION p202408 VALUES LESS THAN (TO_DAYS("2024-09-01")),
        PARTITION p202409 VALUES LESS THAN (TO_DAYS("2024-10-01")),
        PARTITION p202410 VALUES LESS THAN (TO_DAYS("2024-11-01")),
        PARTITION p202411 VALUES LESS THAN (TO_DAYS("2024-12-01")),
        PARTITION p202412 VALUES LESS THAN (TO_DAYS("2025-01-01")),
        PARTITION p202501 VALUES LESS THAN (TO_DAYS("2025-02-01")),
        PARTITION p202502 VALUES LESS THAN (TO_DAYS("2025-03-01")),
        PARTITION p202503 VALUES LESS THAN (TO_DAYS("2025-04-01")),
        PARTITION p202504 VALUES LESS THAN (TO_DAYS("2025-05-01")),
        PARTITION p202505 VALUES LESS THAN (TO_DAYS("2025-06-01")),
        PARTITION p202506 VALUES LESS THAN (TO_DAYS("2025-07-01")),
        PARTITION p202507 VALUES LESS THAN (TO_DAYS("2025-08-01")),
        PARTITION p202508 VALUES LESS THAN (TO_DAYS("2025-09-01")),
        PARTITION p202509 VALUES LESS THAN (TO_DAYS("2025-10-01")),
        PARTITION p202510 VALUES LESS THAN (TO_DAYS("2025-11-01")),
        PARTITION p202511 VALUES LESS THAN (TO_DAYS("2025-12-01")),
        PARTITION p202512 VALUES LESS THAN (TO_DAYS("2026-01-01")),
        PARTITION pmax VALUES LESS THAN MAXVALUE
    )';
-- 表创建模板（显式库名前缀，避免 USE 并发问题）
SET i = 0;
WHILE i < 16 DO
SET @db = CONCAT('etc_', LPAD(i, 2, '0'));
SET @traffic_sql = CONCAT(
        'CREATE TABLE IF NOT EXISTS ',
        @db,
        '.traffic_pass_dev (
                id BIGINT NOT NULL,
                gcsj DATETIME NOT NULL,
                xzqhmc VARCHAR(64),
                adcode INT,
                kkmc VARCHAR(128),
                station_id INT NOT NULL,
                fxlx VARCHAR(16),
                hpzl VARCHAR(16),
                hphm_mask VARCHAR(32),
                clppxh VARCHAR(64),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id, gcsj),
                KEY idx_station_time (station_id, gcsj),
                KEY idx_plate_time (hphm_mask, gcsj),
                KEY idx_created (created_at)
            ) ',
        @traffic_partitions,
        ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;'
    );
PREPARE stmt
FROM @traffic_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @stats_sql = CONCAT(
        'CREATE TABLE IF NOT EXISTS ',
        @db,
        '.stats_realtime (
                id BIGINT PRIMARY KEY AUTO_INCREMENT,
                station_id INT NOT NULL,
                window_start DATETIME NOT NULL,
                window_end DATETIME NOT NULL,
                cnt BIGINT NOT NULL,
                by_dir JSON,
                by_type JSON,
                UNIQUE KEY uk_station_window (station_id, window_start, window_end)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;'
    );
PREPARE stmt
FROM @stats_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @alert_sql = CONCAT(
        'CREATE TABLE IF NOT EXISTS ',
        @db,
        '.alert_plate_clone (
                alert_id BIGINT PRIMARY KEY AUTO_INCREMENT,
                hphm_mask VARCHAR(16),
                first_station_id INT,
                second_station_id INT,
                time_gap_sec BIGINT,
                distance_km DOUBLE,
                speed_kmh DOUBLE,
                confidence DOUBLE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                KEY idx_hphm_mask (hphm_mask),
                KEY idx_created (created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;'
    );
PREPARE stmt
FROM @alert_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET i = i + 1;
END WHILE;
END // DELIMITER;
CALL create_shards();
DROP PROCEDURE create_shards;