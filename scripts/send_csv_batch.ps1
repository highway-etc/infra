Param(
  [string]$Broker = 'localhost:29092',
  [string]$Topic = 'etc_traffic',
  [string]$DataDir = (Join-Path $PSScriptRoot '../flink/data/test_data'),
  [string]$Network = 'infra_etcnet',
  [int]$ChunkSize = 2000,
  [int]$PauseMs = 800,
  [int]$MaxTotal = 5000,  # 0 表示不限制
  [switch]$DryRun
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Console]::InputEncoding = [Text.Encoding]::UTF8

# 检查并运行转换脚本，确保数据是 UTF-8 且包含 XLSX 转换后的 CSV
Write-Host "[send] Running convert_csv.py to ensure data readiness..." -ForegroundColor Yellow
python (Join-Path $PSScriptRoot "convert_csv.py")

# 使用 push_kafka.py 进行投递，它包含车牌脱敏和 JSON 格式化逻辑
$dataPath = (Resolve-Path $DataDir).Path
Write-Host "Sending CSV via push_kafka.py: broker=$Broker topic=$Topic data=$dataPath chunk=$ChunkSize pauseMs=$PauseMs max=$MaxTotal" -ForegroundColor Cyan

if ($DryRun) {
  Write-Host '[send] dry-run mode, skip producing to Kafka' -ForegroundColor DarkYellow
  return
}

$pythonScript = Join-Path $PSScriptRoot "push_kafka.py"
$args = @(
    "--bootstrap", $Broker,
    "--topic", $Topic,
    "--data-dir", $dataPath,
    "--chunk-size", $ChunkSize,
    "--pause-ms", $PauseMs
)

if ($MaxTotal -gt 0) {
    $args += "--max-total"
    $args += $MaxTotal
}

python $pythonScript @args

Write-Host 'Send completed' -ForegroundColor Green
