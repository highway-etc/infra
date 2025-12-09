import argparse, csv, datetime as dt, json, pathlib, zlib
from kafka import KafkaProducer

# 行政区划简单映射，可按需补充
ADCODE_MAP = {
    "邳州市": 320382,
    "丰县": 320321,
    "铜山县": 320312,
    "睢宁县": 320324,
    "沛县": 320322,
    "高速五大队": 999001,
    "新沂市": 320381,
}

def parse_time(s):
    if not s:
        return None
    fmt_candidates = [
        "%Y/%m/%d %H:%M:%S",
        "%Y-%m-%d %H:%M:%S",
        "%Y/%m/%d",
        "%Y-%m-%d",
    ]
    for fmt in fmt_candidates:
        try:
            dt_local = dt.datetime.strptime(s, fmt)
            break
        except ValueError:
            dt_local = None
    if dt_local is None:
        return None
    # 如果没有时间部分，默认 00:00:00；视为北京时间 +08:00
    return dt_local.replace(tzinfo=dt.timezone(dt.timedelta(hours=8))).isoformat()

def station_id_from_kkmc(kkmc: str) -> int:
    if not kkmc:
        return 0
    return (zlib.crc32(kkmc.encode("utf-8")) & 0x7fffffff) % 1000000  # 稳定正整数

def normalize_row(row: dict):
    gcsj_iso = parse_time(row.get("GCSJ"))
    if not gcsj_iso:
        return None
    kkmc = row.get("KKMC", "").strip()
    sid = station_id_from_kkmc(kkmc)
    if sid <= 0:
        return None
    xzqh = row.get("XZQHMC", "").strip()
    return {
        "gcxh": int(row.get("GCXH", 0) or 0),
        "xzqhmc": xzqh,
        "adcode": ADCODE_MAP.get(xzqh, 0),
        "kkmc": kkmc,
        "station_id": sid,
        "fxlx": (row.get("FXLX") or "UNK").strip(),
        "gcsj": gcsj_iso,
        "hpzl": (row.get("HPZL") or "UNK").strip(),
        # 脱敏号牌直接作为 hphm/hphm_mask；如需保留原号牌可另加字段
        "hphm": row.get("SUBSTR(HPHM,1,4)||'***'", "").strip(),
        "hphm_mask": row.get("SUBSTR(HPHM,1,4)||'***'", "").strip(),
        "clppxh": (row.get("CLPPXH") or "").strip(),
    }

def open_csv_reader(path: pathlib.Path):
    """Try UTF-8-SIG first, fallback to GB18030 for mixed-encoding files."""
    try:
        f = path.open("r", encoding="utf-8-sig", newline="")
        return f, csv.DictReader(f)
    except UnicodeDecodeError:
        f = path.open("r", encoding="gb18030", errors="ignore", newline="")
        return f, csv.DictReader(f)


def produce_file(producer, topic, path: pathlib.Path):
    sent = 0
    try:
        f, reader = open_csv_reader(path)
        try:
            for row in reader:
                rec = normalize_row(row)
                if not rec:
                    continue
                producer.send(topic, rec)
                sent += 1
        finally:
            f.close()
    except UnicodeDecodeError:
        # if decode error happened mid-iteration, reopen with gb18030 ignore errors
        with path.open("r", encoding="gb18030", errors="ignore", newline="") as f2:
            reader = csv.DictReader(f2)
            for row in reader:
                rec = normalize_row(row)
                if not rec:
                    continue
                producer.send(topic, rec)
                sent += 1
    producer.flush()
    return sent

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bootstrap", default="localhost:29092", help="Kafka bootstrap servers")
    ap.add_argument("--topic", default="etc_traffic", help="Kafka topic")
    ap.add_argument("--data-dir", default="infra/flink/data/test_data", help="CSV directory")
    args = ap.parse_args()

    prod = KafkaProducer(
        bootstrap_servers=args.bootstrap,
        value_serializer=lambda v: json.dumps(v, ensure_ascii=False).encode("utf-8"),
        linger_ms=50,
        batch_size=64 * 1024,
        acks="all",
    )

    data_dir = pathlib.Path(args.data_dir)
    total = 0
    for csv_path in sorted(data_dir.glob("*.csv")):
        n = produce_file(prod, args.topic, csv_path)
        print(f"{csv_path.name}: sent {n}")
        total += n
    print(f"done, total sent: {total}")

if __name__ == "__main__":
    main()