#!/usr/bin/env bash
set -euo pipefail

N=${N:-100}
BROKER=${BROKER:-kafka:9092}
TOPIC=${TOPIC:-etc_traffic}
KAFKA_CONTAINER=${KAFKA_CONTAINER:-kafka}

echo "Sending ${N} mock records to ${TOPIC} via ${BROKER} (container=${KAFKA_CONTAINER})"

docker exec -i "${KAFKA_CONTAINER}" bash -lc "set -e; seq 1 ${N} | while read i; do \
  ts=\$(date -u +%Y-%m-%dT%H:%M:%SZ); \
  sid=\$(( (RANDOM % 10) + 100 )); \
  printf '{"gcxh":%s,"xzqhmc":"杭州","adcode":330100,"kkmc":"卡口%s","station_id":%s,"fxlx":"IN","gcsj":"%s","hpzl":"蓝牌","hphm":"浙A12345","hphm_mask":"浙A%04d****","clppxh":"丰田"}\n' "\$i" "\$sid" "\$sid" "\$ts" "\$RANDOM"; \
 done | kafka-console-producer --bootstrap-server "${BROKER}" --topic "${TOPIC}" --producer-property acks=all --producer-property linger.ms=10"

echo "Done."
