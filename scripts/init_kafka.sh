#!/usr/bin/env bash
set -e
BROKER=${1:-localhost:9092}
TOPIC=${2:-etc_traffic}
docker exec -it $(docker ps --filter "ancestor=bitnami/kafka:3.6" -q | head -n1) \
  kafka-topics.sh --create --topic "$TOPIC" --partitions 3 --replication-factor 1 --bootstrap-server "$BROKER" || true
echo "Kafka topic $TOPIC ready."