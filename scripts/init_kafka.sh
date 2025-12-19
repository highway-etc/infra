#!/usr/bin/env bash
set -e
BROKER=${1:-kafka:9092}
TOPIC=${2:-etc_traffic}
PARTITIONS=${3:-6}

docker exec kafka kafka-topics --create --if-not-exists --topic "$TOPIC" \
  --bootstrap-server "$BROKER" --partitions "$PARTITIONS" --replication-factor 1

# 若已存在但分区数不足，尝试扩容到 PARTITIONS
docker exec kafka kafka-topics --alter --topic "$TOPIC" \
  --bootstrap-server "$BROKER" --partitions "$PARTITIONS" || true

echo "Topics:"
docker exec kafka kafka-topics --list --bootstrap-server "$BROKER"