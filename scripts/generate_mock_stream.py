#!/usr/bin/env python
"""
高频仿真数据生成脚本：从样本 CSV 推断字段并持续向 Kafka 写入 JSON 事件。
特性：
高频仿真数据生成脚本：从样本 CSV 提取车型/号牌模板，持续向 Kafka 写入 JSON 事件。
特性：
- 默认每秒 80 条（可通过 --rate 调整），确保 >=50 条/秒的实时性。
- 车牌省份覆盖全国，城市代码按真实可用字母生成（不再出现 “W 城市” 之类异常），并可对“苏”牌适度加权。
- 站点遍布全国，行政区划/站点名称多样化；自动注入一定比例套牌数据（默认 8%）。
- 为 hpzl 提供语义化车型名称，事件中同时携带 code 和 name，UTF-8 发送保证中文显示正常。

使用示例：
  python generate_mock_stream.py --bootstrap localhost:29092 --topic etc_traffic --rate 80 --clone-rate 0.1
  python generate_mock_stream.py --max-events 2000  # 发送指定条数后退出
按 Ctrl+C 可安全退出。
"""
import argparse
import csv
import datetime as dt
import json
import pathlib
import random
import time
from collections import deque

from kafka import KafkaProducer

TZ = dt.timezone(dt.timedelta(hours=8))

PLATE_CITY_POOL = {
    "京": list("ABCDE"),
    "津": list("AB"),
    "冀": list("ABCDEFGHR"),
    "晋": list("ABCEFKM"),
    "蒙": list("ABCDEFGHJKL"),
    "辽": list("ABCDEFGHJ"),
    "吉": list("ABCDEFGHJ"),
    "黑": list("ABCDEFGHJR"),
    "沪": list("ABCD"),
    "苏": list("ABCDEFGHJKLMN"),
    "浙": list("ABCDEFGHJKL"),
    "皖": list("ABCDEFGHJKLMN"),
    "闽": list("ABCDEFGHJK"),
    "赣": list("ABCDEFGHJK"),
    "鲁": list("ABCDEFGHIJKLMNPRSUV"),
    "豫": list("ABCDEFGHIJKLMNPRSU"),
    "鄂": list("ABCDEFGHJKLPRS"),
    "湘": list("ABCDEFGHIJKLMNU"),
    "粤": list("ABCDEFGHJKLMNPRSTUVY"),
    "桂": list("ABCDEFGHJKLMNPR"),
    "琼": list("ABCD"),
    "渝": list("ABC"),
    "川": list("ABCDEFHJKLQRSTUV"),
    "贵": list("ABCDEFGHJ"),
    "云": list("ABCDEFGHIJKLMNPRS"),
    "藏": list("ABCDEFGHJKLMNPRS"),
    "陕": list("ABCDEFGHIJKLMN"),
    "甘": list("ABCDEFGHIJKLMNPR"),
    "青": list("ABCDEFGHIJKLMNP"),
    "宁": list("ABCDEFGH"),
    "新": list("ABCDEFGHJKLMNPRS"),
}

STATIONS = [
    {"id": 101, "kkmc": "南京江北站", "xzqhmc": "江苏省南京市", "adcode": 320100, "plate_prefix": "苏A"},
    {"id": 102, "kkmc": "苏州阳澄湖站", "xzqhmc": "江苏省苏州市", "adcode": 320500, "plate_prefix": "苏E"},
    {"id": 103, "kkmc": "无锡惠山站", "xzqhmc": "江苏省无锡市", "adcode": 320200, "plate_prefix": "苏B"},
    {"id": 104, "kkmc": "北京大兴机场站", "xzqhmc": "北京市大兴区", "adcode": 110115, "plate_prefix": "京D"},
    {"id": 105, "kkmc": "上海浦东川沙站", "xzqhmc": "上海市浦东新区", "adcode": 310115, "plate_prefix": "沪C"},
    {"id": 106, "kkmc": "广州花都站", "xzqhmc": "广东省广州市", "adcode": 440114, "plate_prefix": "粤A"},
    {"id": 107, "kkmc": "深圳南山站", "xzqhmc": "广东省深圳市", "adcode": 440305, "plate_prefix": "粤B"},
    {"id": 108, "kkmc": "重庆绕城北站", "xzqhmc": "重庆市渝北区", "adcode": 500112, "plate_prefix": "渝B"},
    {"id": 109, "kkmc": "成都绕城东站", "xzqhmc": "四川省成都市", "adcode": 510100, "plate_prefix": "川A"},
    {"id": 110, "kkmc": "济南东站", "xzqhmc": "山东省济南市", "adcode": 370102, "plate_prefix": "鲁A"},
    {"id": 111, "kkmc": "郑州航空港站", "xzqhmc": "河南省郑州市", "adcode": 410184, "plate_prefix": "豫A"},
    {"id": 112, "kkmc": "武汉北三环站", "xzqhmc": "湖北省武汉市", "adcode": 420102, "plate_prefix": "鄂A"},
    {"id": 113, "kkmc": "西安绕城南站", "xzqhmc": "陕西省西安市", "adcode": 610116, "plate_prefix": "陕A"},
    {"id": 114, "kkmc": "合肥肥东站", "xzqhmc": "安徽省合肥市", "adcode": 340122, "plate_prefix": "皖A"},
    {"id": 115, "kkmc": "福州南通道站", "xzqhmc": "福建省福州市", "adcode": 350121, "plate_prefix": "闽A"},
    {"id": 116, "kkmc": "杭州临安站", "xzqhmc": "浙江省杭州市", "adcode": 330127, "plate_prefix": "浙A"},
    {"id": 117, "kkmc": "乌鲁木齐绕城站", "xzqhmc": "新疆乌鲁木齐市", "adcode": 650100, "plate_prefix": "新A"},
    {"id": 118, "kkmc": "拉萨柳梧站", "xzqhmc": "西藏拉萨市", "adcode": 540100, "plate_prefix": "藏A"},
]

VEHICLE_TYPES = [
    ("02", "小型汽车", 0.55),
    ("01", "大型汽车", 0.12),
    ("52", "新能源小型", 0.12),
    ("53", "新能源大型", 0.05),
    ("21", "出租客运", 0.05),
    ("23", "警用车辆", 0.02),
    ("16", "教练汽车", 0.04),
    ("24", "消防车辆", 0.02),
    ("25", "救护车辆", 0.03)
]

HPZL_NAME_MAP = {code: name for code, name, _ in VEHICLE_TYPES}
ALNUM = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789"


def open_csv_reader(path: pathlib.Path):
    try:
        fh = path.open("r", encoding="utf-8", errors="strict", newline="")
        fh.read(1)
        fh.seek(0)
    except UnicodeDecodeError:
        try:
            fh.close()
        except Exception:
            pass
        fh = path.open("r", encoding="gb18030", errors="replace", newline="")
    return fh, csv.DictReader(fh)


def load_seed_templates(data_dir: pathlib.Path):
    seeds = []
    for csv_path in sorted(data_dir.glob("*.csv")):
        try:
            fh, reader = open_csv_reader(csv_path)
            with fh:
                for row in reader:
                    hpzl_code = (row.get("HPZL") or row.get("hpzl") or "02").strip()
                    seeds.append({
                        "hpzl": hpzl_code,
                        "hpzl_name": HPZL_NAME_MAP.get(hpzl_code, "小型汽车"),
                        "clppxh": (row.get("CLPPXH") or row.get("clppxh") or "未知车型").strip(),
                        "fxlx": (row.get("FXLX") or row.get("fxlx") or random.choice(["IN", "OUT"])).strip()
                    })
        except Exception:
            continue
    if not seeds:
        seeds = [{"hpzl": "02", "hpzl_name": "小型汽车", "clppxh": "小型汽车", "fxlx": "IN"}]
    return seeds


def weighted_choice(options):
    r = random.random()
    cumulative = 0.0
    for code, name, weight in options:
        cumulative += weight
        if r <= cumulative:
            return {"code": code, "name": name}
    code, name, _ = options[-1]
    return {"code": code, "name": name}


def pick_vehicle_type(template=None):
    if template and template.get("hpzl"):
        code = template.get("hpzl")
        return {"code": code, "name": template.get("hpzl_name") or HPZL_NAME_MAP.get(code, "小型汽车")}
    return weighted_choice(VEHICLE_TYPES)


def choose_plate_prefix(station_prefix: str, focus_prefix: str, focus_ratio: float) -> str:
    def expand(prefix: str) -> str:
        if not prefix:
            return ""
        prov = prefix[0]
        letters = PLATE_CITY_POOL.get(prov)
        if not letters:
            return ""
        if len(prefix) >= 2 and prefix[1] in letters:
            return prov + prefix[1]
        return prov + random.choice(letters)

    if focus_prefix and random.random() < focus_ratio:
        expanded = expand(focus_prefix)
        if expanded:
            return expanded

    expanded = expand(station_prefix)
    if expanded:
        return expanded

    prov, letters = random.choice(list(PLATE_CITY_POOL.items()))
    return prov + random.choice(letters)


def random_plate(prefix: str) -> str:
    normalized = prefix if prefix else "无牌"
    return normalized + "".join(random.choice(ALNUM) for _ in range(5))


def mask_plate(plate: str) -> str:
    if len(plate) <= 4:
        return plate + "***"
    return plate[:2] + plate[2:5] + "***"


def build_event(template, station, plate, vehicle, gcsj_iso, gcxh):
    return {
        "gcxh": gcxh,
        "xzqhmc": station["xzqhmc"],
        "adcode": station["adcode"],
        "kkmc": station["kkmc"],
        "station_id": station["id"],
        "fxlx": template.get("fxlx") or random.choice(["IN", "OUT"]),
        "gcsj": gcsj_iso,
        "hpzl": template.get("hpzl") or vehicle["code"],
        "hpzl_name": template.get("hpzl_name") or vehicle["name"],
        "vehicle_type": template.get("hpzl_name") or vehicle["name"],
        "hphm": plate,
        "hphm_mask": mask_plate(plate),
        "clppxh": template.get("clppxh") or vehicle["name"],
    }


def main():
    ap = argparse.ArgumentParser(description="实时仿真数据生成器")
    ap.add_argument("--bootstrap", default="localhost:29092", help="Kafka bootstrap servers")
    ap.add_argument("--topic", default="etc_traffic", help="Kafka topic")
    ap.add_argument("--data-dir", default=str(pathlib.Path(__file__).parent.parent / "flink" / "data" / "test_data"),
                    help="种子 CSV 目录，用于提取车型/号牌类型等模板")
    ap.add_argument("--rate", type=int, default=80, help="每秒发送条数，默认80，至少应 >=50")
    ap.add_argument("--clone-rate", type=float, default=0.02, help="套牌事件占比，默认 2%")
    ap.add_argument("--max-events", type=int, default=0, help="发送上限，0 表示无限流")
    ap.add_argument("--focus-prefix", default="苏", help="优先生成的号牌省份前缀")
    ap.add_argument("--focus-ratio", type=float, default=0.35, help="命中优先省份的概率")
    ap.add_argument("--time-skew", type=int, default=900, help="事件时间相对于当前的随机偏移秒数")
    ap.add_argument("--log-every", type=int, default=1000, help="日志打印间隔")
    args = ap.parse_args()

    data_dir = pathlib.Path(args.data_dir)
    seeds = load_seed_templates(data_dir)
    print(f"[gen] loaded {len(seeds)} seed rows from {data_dir}")

    producer = KafkaProducer(
        bootstrap_servers=args.bootstrap,
        value_serializer=lambda v: json.dumps(v, ensure_ascii=False).encode("utf-8"),
        linger_ms=20,
        batch_size=64 * 1024,
        acks="all",
    )

    recent = deque(maxlen=8000)
    counter = 0
    gcxh = 1
    try:
        while True:
            loop_start = time.perf_counter()
            now = dt.datetime.now(tz=TZ)
            for _ in range(args.rate):
                is_clone = (recent and random.random() < args.clone_rate)
                if is_clone:
                    base = random.choice(list(recent))
                    plate = base["plate"]
                    template = base["template"]
                    vehicle = base.get("vehicle") or pick_vehicle_type(template)
                    station_candidates = [s for s in STATIONS if s["id"] != base["station_id"]]
                    station = random.choice(station_candidates or STATIONS)
                    # 将套牌时间分散到更长窗口，降低同刻并发
                    gcsj = base["gcsj"] + dt.timedelta(seconds=random.randint(120, 900))
                else:
                    station = random.choice(STATIONS)
                    template = random.choice(seeds)
                    vehicle = pick_vehicle_type(template)
                    prefix = choose_plate_prefix(station.get("plate_prefix"), args.focus_prefix, args.focus_ratio)
                    plate = random_plate(prefix)
                    skew = random.randint(0, max(args.time_skew, 1))
                    gcsj = now - dt.timedelta(seconds=skew)

                event = build_event(template, station, plate, vehicle, gcsj.isoformat(), gcxh)
                producer.send(args.topic, event)

                recent.append({"plate": plate, "gcsj": gcsj, "station_id": station["id"], "template": template, "vehicle": vehicle})
                counter += 1
                gcxh += 1
                if args.max_events and counter >= args.max_events:
                    break
                if counter % args.log_every == 0:
                    print(f"[gen] sent {counter} events, latest plate={plate}, station={station['kkmc']}")
            producer.flush()
            if args.max_events and counter >= args.max_events:
                break
            elapsed = time.perf_counter() - loop_start
            sleep_sec = 1 - elapsed
            if sleep_sec > 0:
                time.sleep(sleep_sec)
    except KeyboardInterrupt:
        print("[gen] interrupted by user, flushing...")
    finally:
        producer.flush()
        producer.close()
        print(f"[gen] total sent: {counter}")


if __name__ == "__main__":
    main()
