import argparse, csv, datetime as dt, json, pathlib, zlib, time, random
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

HPZL_MAP = {
    "01": "大型汽车",
    "02": "小型汽车",
    "03": "使馆汽车",
    "04": "领馆汽车",
    "05": "境外汽车",
    "06": "外籍汽车",
    "07": "普通摩托车",
    "08": "轻便摩托车",
    "16": "教练汽车",
    "20": "公交客车",
    "21": "出租客运",
    "22": "旅游客车",
    "23": "警用车辆",
    "24": "消防车辆",
    "25": "救护车辆",
    "26": "工程救险",
    "31": "武警车辆",
    "32": "军队车辆",
    "51": "大功率摩托",
    "52": "新能源小型",
    "53": "新能源大型",
    "54": "新能源货车",
    "1": "小型汽车",
    "2": "大型汽车"
}


def normalize_row(row: dict):
    # Robustly find columns
    gcsj_val = ""
    gcxh_val = "0"
    kkmc = ""
    xzqh = ""
    fxlx = "UNK"
    hpzl = "UNK"
    plate = ""
    clppxh = ""

    for key, val in row.items():
        ukey = key.upper()
        if "GCSJ" in ukey or "时间" in ukey:
            gcsj_val = (val or "").strip()
        elif "GCXH" in ukey or "序号" in ukey:
            # Handle 'G'||GCXH case by stripping non-digits if needed, 
            # but usually it's just a string ID
            gcxh_val = "".join(filter(str.isdigit, str(val or "0"))) or "0"
        elif "KKMC" in ukey or "卡口名称" in ukey:
            kkmc = (val or "").strip()
        elif "XZQHMC" in ukey or "行政区划" in ukey:
            xzqh = (val or "").strip()
        elif "FXLX" in ukey or "方向" in ukey:
            fxlx = (val or "UNK").strip()
        elif "HPZL" in ukey or "号牌种类" in ukey:
            hpzl = (val or "UNK").strip()
        elif "HPHM" in ukey or "号牌号码" in ukey:
            plate = (val or "").strip()
        elif "CLPPXH" in ukey or "品牌" in ukey:
            clppxh = (val or "").strip()

    gcsj_iso = parse_time(gcsj_val)
    if not gcsj_iso:
        return None
    
    sid = station_id_from_kkmc(kkmc)
    if sid <= 0:
        return None

    # Normalize direction to IN/OUT with some diversity
    dir_upper = (fxlx or "").upper()
    if "入" in fxlx or "IN" in dir_upper:
        direction = "IN"
    elif "出" in fxlx or "OUT" in dir_upper:
        direction = "OUT"
    else:
        direction = random.choice(["IN", "OUT"])

    hpzl_code = hpzl.zfill(2) if hpzl.isdigit() and len(hpzl) < 2 else hpzl
    hpzl_name = HPZL_MAP.get(hpzl_code, HPZL_MAP.get(hpzl, hpzl or "未知车型"))
    model = clppxh or hpzl_name
            
    return {
        "gcxh": int(gcxh_val),
        "xzqhmc": xzqh,
        "adcode": ADCODE_MAP.get(xzqh, 0),
        "kkmc": kkmc,
        "station_id": sid,
        "fxlx": direction,
        "gcsj": gcsj_iso,
        "hpzl": hpzl_code,
        "hphm": plate,
        "hphm_mask": plate,
        "clppxh": model,
        "vehicle_type": hpzl_name,
        "hpzl_name": hpzl_name,
    }

def open_csv_reader(path: pathlib.Path):
    """优先用 UTF-8 读取，失败再回退 GB18030，避免截断探测导致误判."""
    try:
        f = path.open("r", encoding="utf-8", errors="strict", newline="")
        # 读一点校验编码，再回到起始位置
        f.read(1)
        f.seek(0)
    except UnicodeDecodeError:
        try:
            f.close()
        except Exception:
            pass
        f = path.open("r", encoding="gb18030", errors="replace", newline="")
    return f, csv.DictReader(f)


def produce_file(producer, topic, path: pathlib.Path, chunk_size: int, pause_sec: float, max_total: int | None = None):
    """Produce one CSV file with throttling by chunk size and pause."""
    sent = 0

    def _emit_rows(reader):
        nonlocal sent
        for row in reader:
            if max_total is not None and sent >= max_total:
                break
            rec = normalize_row(row)
            if not rec:
                continue
            producer.send(topic, rec)
            sent += 1
            if sent % chunk_size == 0:
                producer.flush()
                if pause_sec > 0:
                    time.sleep(pause_sec)

    try:
        f, reader = open_csv_reader(path)
        try:
            _emit_rows(reader)
        finally:
            f.close()
    except UnicodeDecodeError:
        with path.open("r", encoding="gb18030", errors="ignore", newline="") as f2:
            reader = csv.DictReader(f2)
            _emit_rows(reader)

    producer.flush()
    return sent

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bootstrap", default="localhost:29092", help="Kafka bootstrap servers")
    ap.add_argument("--topic", default="etc_traffic", help="Kafka topic")
    ap.add_argument("--data-dir", default="infra/flink/data/test_data", help="CSV directory")
    ap.add_argument("--chunk-size", type=int, default=2000, help="Messages to send before flush+pause")
    ap.add_argument("--pause-ms", type=int, default=800, help="Pause milliseconds after each chunk")
    ap.add_argument("--max-total", type=int, default=None, help="Optional cap of messages per run")
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
    pause_sec = max(args.pause_ms, 0) / 1000.0
    for csv_path in sorted(data_dir.glob("*.csv")):
        if args.max_total is not None and total >= args.max_total:
            break
        remaining = None if args.max_total is None else max(args.max_total - total, 0)
        n = produce_file(prod, args.topic, csv_path, args.chunk_size, pause_sec, remaining)
        print(f"{csv_path.name}: sent {n}")
        total += n
    print(f"done, total sent: {total}")

if __name__ == "__main__":
    main()