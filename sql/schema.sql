CREATE DATABASE IF NOT EXISTS etc_traffic_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE etc_traffic_db;
-- 明细表（与你的 MySqlBatchSink 插入字段一致）
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
);
-- 窗口统计
CREATE TABLE IF NOT EXISTS stats_realtime (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    station_id INT NOT NULL,
    window_start TIMESTAMP NOT NULL,
    window_end TIMESTAMP NOT NULL,
    cnt BIGINT NOT NULL,
    by_dir JSON,
    by_type JSON,
    UNIQUE KEY uk_station_window (station_id, window_start, window_end)
);
-- 套牌告警
CREATE TABLE IF NOT EXISTS alert_plate_clone (
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
);