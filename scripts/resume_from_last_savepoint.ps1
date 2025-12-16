Param(
  [string]$JobManager = "flink-jobmanager",
  [string]$JarPath = "/opt/flink/usrlib/streaming-0.1.0.jar",
  [string[]]$MainClasses = @(
    "com.highway.etc.job.TrafficStreamingJob",
    "com.highway.etc.job.PlateCloneDetectionJob"
  )
)

Write-Host "查找最新的 savepoint 目录 ..."
$lastSp = (docker exec -i $JobManager sh -lc "ls -1t /flink-data/savepoints | head -1" 2>$null).Trim()

if ([string]::IsNullOrWhiteSpace($lastSp)) {
  Write-Error "未找到任何 savepoint，请先执行 savepoint_and_stop.ps1。"
  exit 1
}

Write-Host "使用保存点：$lastSp"
foreach ($cls in $MainClasses) {
  $cmdRun = "/opt/flink/bin/flink run -d -s file:///flink-data/savepoints/$lastSp -c $cls $JarPath"
  Write-Host "从保存点恢复：$cls"
  docker exec -i $JobManager sh -lc $cmdRun
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "恢复 $cls 失败，请查看 JobManager 日志。"
  }
}

Write-Host "恢复命令已执行完成，请到 Flink Web UI 查看状态。"