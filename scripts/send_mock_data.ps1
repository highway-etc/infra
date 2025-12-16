Param(
  [int]$N = 100,
  [string]$Broker = "kafka:9092",
  [string]$Topic = "etc_traffic",
  [string]$KafkaContainer = "kafka"
)

Write-Host "向 Kafka 发送 $N 条模拟数据，broker=$Broker, topic=$Topic ..."
# 说明：
# - 这里将 N/BROKER/TOPIC 作为变量注入容器，然后用 bash 循环 echo JSON
# - JSON 构造使用 printf，避免转义混乱；字段与你的 Flink 反序列化保持一致
$cmdTemplate = @'
N={0} BROKER="{1}" TOPIC="{2}" bash -lc '
for i in $(seq 1 $N); do
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  sid=$(( (RANDOM % 10) + 100 ))  # 100~109
  # 这里 plate 仅用于 mask 展示
  printf "{{\"gcxh\":%s,\"xzqhmc\":\"杭州\",\"adcode\":330100,\"kkmc\":\"卡口%s\",\"station_id\":%s,\"fxlx\":\"IN\",\"gcsj\":\"%s\",\"hpzl\":\"蓝牌\",\"hphm\":\"浙A12345\",\"hphm_mask\":\"浙A%04d****\",\"clppxh\":\"丰田\"}}\n" "$i" "$sid" "$sid" "$ts" "$RANDOM"
done | kafka-console-producer --bootstrap-server "$BROKER" --topic "$TOPIC"
'
'@

# 将参数格式化进命令（这里字符串使用 .NET Format，避免 PowerShell 对 $ 的干扰）
$cmd = [string]::Format($cmdTemplate, $N, $Broker, $Topic)

docker exec -i $KafkaContainer sh -lc $cmd

if ($LASTEXITCODE -eq 0) {
  Write-Host "已发送 $N 条消息到 $Topic。"
} else {
  Write-Warning "发送失败，请检查 kafka 容器与主题是否存在。"
}