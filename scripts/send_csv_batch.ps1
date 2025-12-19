Param(
  [string]$Broker = 'kafka:9092',
  [string]$Topic = 'etc_traffic',
  [string]$DataDir = (Join-Path $PSScriptRoot '../flink/data/test_data'),
  [string]$Network = 'infra_etcnet',
  [string]$PythonImage = 'python:3.11-slim',
  [int]$ChunkSize = 2000,
  [int]$PauseMs = 800,
  [int]$MaxTotal = 0  # 0 表示不限制
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Console]::InputEncoding = [Text.Encoding]::UTF8

#将 CSV 批量投递到 Kafka，使用临时 Python 容器运行 push_kafka.py
$dataPath = (Resolve-Path $DataDir).Path
$scriptPath = (Resolve-Path (Join-Path $PSScriptRoot 'push_kafka.py')).Path

Write-Host "Sending CSV to Kafka: broker=$Broker topic=$Topic data=$dataPath" -ForegroundColor Cyan

$innerCmd = @(
  'pip install -q kafka-python',
  "python /app/push_kafka.py --bootstrap $Broker --topic $Topic --data-dir /data --chunk-size $ChunkSize --pause-ms $PauseMs" + $(if ($MaxTotal -gt 0) { " --max-total $MaxTotal" } else { '' })
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
