Param(
  [string]$Broker = 'kafka:9092',
  [string]$Topic = 'etc_traffic',
  [string]$DataDir = (Join-Path $PSScriptRoot '../flink/data/test_data'),
  [string]$Network = 'infra_etcnet',
  [string]$PythonImage = 'python:3.11-slim'
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Console]::InputEncoding = [Text.Encoding]::UTF8

# 将 CSV 批量投递到 Kafka，使用临时 Python 容器运行 push_kafka.py
$dataPath = (Resolve-Path $DataDir).Path
$scriptPath = (Resolve-Path (Join-Path $PSScriptRoot 'push_kafka.py')).Path

Write-Host "Sending CSV to Kafka: broker=$Broker topic=$Topic data=$dataPath" -ForegroundColor Cyan

$innerCmd = @(
  'pip install -q kafka-python',
  "python /app/push_kafka.py --bootstrap $Broker --topic $Topic --data-dir /data"
) -join ' && '

$dockerArgs = @(
  'run', '--rm',
  '--network', $Network,
  '-v', "${dataPath}:/data:ro",
  '-v', "${scriptPath}:/app/push_kafka.py:ro",
  $PythonImage,
  'bash', '-lc', $innerCmd
)

docker @dockerArgs

Write-Host 'Send completed' -ForegroundColor Green
