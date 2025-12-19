Param(
  [int]$N = 100,
  [string]$Broker = "kafka:9092",
  [string]$Topic = "etc_traffic",
  [string]$KafkaContainer = "kafka"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 确保 param 是首个语句；编码已在上方设置

Write-Host "Sending $N mock records to Kafka, broker=$Broker, topic=$Topic ..."
# 说明：
# - 用 bash 生成 JSON，并直接通过 kafka-console-producer 写入。
# - 仅使用 Flink 识别的字段，避免 JSON schema 偏差。
# - 使用 bash -lc 保持变量可见；seq 在镜像中可用，若失败改回 while。
$cmdTemplate = @'
set -e
N={0}
BROKER="{1}"
TOPIC="{2}"

echo "Producing ${N} messages to ${TOPIC} via ${BROKER} ..."
seq 1 ${N} | while read i; do
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  sid=$(( (RANDOM % 10) + 100 ))  # 100~109
  printf "{{\"gcxh\":%s,\"xzqhmc\":\"杭州\",\"adcode\":330100,\"kkmc\":\"卡口%s\",\"station_id\":%s,\"fxlx\":\"IN\",\"gcsj\":\"%s\",\"hpzl\":\"蓝牌\",\"hphm\":\"浙A12345\",\"hphm_mask\":\"浙A%04d****\",\"clppxh\":\"丰田\"}}\n" "$i" "$sid" "$sid" "$ts" "$RANDOM"
done | kafka-console-producer --bootstrap-server "${BROKER}" --topic "${TOPIC}" --producer-property acks=all --producer-property linger.ms=10
echo "Done."
'@

# 将参数格式化进命令（这里字符串使用 .NET Format，避免 PowerShell 对 $ 的干扰）
$cmd = [string]::Format($cmdTemplate, $N, $Broker, $Topic)

docker exec -i $KafkaContainer bash -lc $cmd

if ($LASTEXITCODE -eq 0) {
  Write-Host "Sent $N messages to $Topic."
} else {
  Write-Warning "Send failed. Check kafka container and topic exist."
}