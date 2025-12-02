#!/usr/bin/env bash
set -e
BROKER=${1:-kafka:9092}
TOPIC=${2:-etc_traffic}

docker exec -it kafka kafka-topics --create --if-not-exists --topic "$TOPIC" \
  --bootstrap-server "$BROKER" --partitions 3 --replication-factor 1

echo "Topics:"
docker exec -it kafka kafka-topics --list --bootstrap-server "$BROKER"