Param(
  [string]$Broker = 'kafka:9092',
  [string]$Topic = 'etc_traffic',
  [string]$DataDir = (Join-Path $PSScriptRoot '../flink/data/test_data'),
  [string]$Network = 'infra_etcnet',
  [int]$ChunkSize = 500,
  [int]$PauseMs = 1200,
  [int]$MaxTotal = 5000,  # 0 表示不限制
  [switch]$DryRun
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Console]::InputEncoding = [Text.Encoding]::UTF8

# 将 CSV 批量投递到 Kafka，改用已有的 cp-kafka 镜像的 kafka-console-producer，避免临时拉取 python/pip 卡住
$dataPath = (Resolve-Path $DataDir).Path
Write-Host "Sending CSV via kafka-console-producer: broker=$Broker topic=$Topic data=$dataPath chunk=$ChunkSize pauseMs=$PauseMs max=$MaxTotal" -ForegroundColor Cyan

if ($DryRun) {
  Write-Host '[send] dry-run mode, skip producing to Kafka' -ForegroundColor DarkYellow
  return
}

# 在容器内用 split 分批，每批发送后 sleep，再按 MaxTotal 限制总量
$innerCmd = @(
  'set -euo pipefail',
  'shopt -s nullglob',
  'total=0',
  'for f in /data/*.csv; do',
  '  echo "[send] file=$f";',
  '  tail -n +2 "$f" | split -l ' + $ChunkSize + ' - batch_',
  '  for b in batch_*; do',
  '    batch_lines=$(wc -l < "$b")',
  '    kafka-console-producer --broker-list ' + $Broker + ' --topic ' + $Topic + ' < "$b"',
  '    total=$((total + batch_lines))',
  '    rm -f "$b"',
  '    echo "[send] batch=$batch_lines total=$total"',
  '    if [ ' + $MaxTotal + ' -gt 0 ] && [ $total -ge ' + $MaxTotal + ' ]; then echo "[send] reached max=$total"; exit 0; fi',
  '    sleep ' + ([math]::Round($PauseMs / 1000, 3)) + '',
  '  done',
  'done',
  'echo "[send] finished total=$total"'
) -join ' && '

$dockerArgs = @(
  'run', '--rm',
  '--network', $Network,
  '-v', "${dataPath}:/data:ro",
  'confluentinc/cp-kafka:7.5.3',
  'bash', '-lc', $innerCmd
)

docker @dockerArgs

Write-Host 'Send completed' -ForegroundColor Green
