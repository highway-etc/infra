CREATE TABLE IF NOT EXISTS traffic_pass_dev (
    pk_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    gcsj DATETIME(3),
    xzqhmc VARCHAR(64),
    adcode INT,
    kkmc VARCHAR(128),
    station_id INT,
    fxlx VARCHAR(16),
    hpzl VARCHAR(16),
    hphm_mask VARCHAR(16),
    clppxh VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS stats_realtime (
    station_id INT,
    window_start DATETIME(3),
    window_end DATETIME(3),
    cnt BIGINT,
    by_dir JSON,
    by_type JSON,
    PRIMARY KEY (station_id, window_start)
);