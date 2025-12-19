-- 初始化 16 个分片库与表结构（兼容 MySQL 5.7 + MyCAT 1.6）
-- 由于 MySQL 5.7 对 PREPARE DROP/CREATE 的限制，在这里展开为静态 SQL。

-- 先删除旧分片库（如存在）
DROP DATABASE IF EXISTS etc_00;
DROP DATABASE IF EXISTS etc_01;
DROP DATABASE IF EXISTS etc_02;
DROP DATABASE IF EXISTS etc_03;
DROP DATABASE IF EXISTS etc_04;
DROP DATABASE IF EXISTS etc_05;
DROP DATABASE IF EXISTS etc_06;
DROP DATABASE IF EXISTS etc_07;
DROP DATABASE IF EXISTS etc_08;
DROP DATABASE IF EXISTS etc_09;
DROP DATABASE IF EXISTS etc_10;
DROP DATABASE IF EXISTS etc_11;
DROP DATABASE IF EXISTS etc_12;
DROP DATABASE IF EXISTS etc_13;
DROP DATABASE IF EXISTS etc_14;
DROP DATABASE IF EXISTS etc_15;

-- 通用表定义
CREATE DATABASE IF NOT EXISTS etc_00 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_01 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_02 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_03 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_04 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_05 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_06 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_07 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_08 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_09 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_10 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_11 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_12 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_13 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_14 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS etc_15 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- 为每个分片创建三张表（静态展开，避免循环语法差异）

-- etc_00
USE etc_00;
CREATE TABLE IF NOT EXISTS traffic_pass_dev (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  gcsj TIMESTAMP NULL,
  xzqhmc VARCHAR(64),
  adcode INT,
  kkmc VARCHAR(128),
  station_id INT,
  fxlx VARCHAR(16),
  hpzl VARCHAR(16),
  hphm_mask VARCHAR(32),
  clppxh VARCHAR(64),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_station_time (station_id, gcsj),
  KEY idx_created (created_at)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS stats_realtime (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  station_id INT NOT NULL,
  window_start TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  window_end TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  cnt BIGINT NOT NULL,
  by_dir JSON,
  by_type JSON,
  UNIQUE KEY uk_station_window (station_id, window_start, window_end)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS alert_plate_clone (
  alert_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  hphm_mask VARCHAR(32),
  first_station_id INT,
  second_station_id INT,
  time_gap_sec BIGINT,
  distance_km DOUBLE,
  speed_kmh DOUBLE,
  confidence DOUBLE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_hphm_mask (hphm_mask),
  KEY idx_created (created_at)
) ENGINE=InnoDB;

-- etc_01
USE etc_01;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_02
USE etc_02;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_03
USE etc_03;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_04
USE etc_04;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_05
USE etc_05;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_06
USE etc_06;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_07
USE etc_07;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_08
USE etc_08;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_09
USE etc_09;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_10
USE etc_10;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_11
USE etc_11;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_12
USE etc_12;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_13
USE etc_13;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_14
USE etc_14;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

-- etc_15
USE etc_15;
CREATE TABLE IF NOT EXISTS traffic_pass_dev LIKE etc_00.traffic_pass_dev;
CREATE TABLE IF NOT EXISTS stats_realtime LIKE etc_00.stats_realtime;
CREATE TABLE IF NOT EXISTS alert_plate_clone LIKE etc_00.alert_plate_clone;

CREATE USER IF NOT EXISTS 'etcuser'@'%' IDENTIFIED BY 'etcpass';
GRANT ALL PRIVILEGES ON `etc_%`.* TO 'etcuser'@'%';
FLUSH PRIVILEGES;
