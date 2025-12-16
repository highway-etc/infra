Param(
  [string]$JobManager = "flink-jobmanager",
  [string]$SavepointDir = "file:///flink-data/savepoints"
)

Write-Host "查询 RUNNING 的 Flink JobID ..."
# 注意 PowerShell 中 $ 需要转义为 `$
$cmdList = "/opt/flink/bin/flink list | awk '/RUNNING/{print `$4}'"
$jobIdsText = docker exec -i $JobManager sh -lc $cmdList 2>$null
$jobIds = @()
if ($jobIdsText) {
  $jobIds = ($jobIdsText -split "`r?`n") | Where-Object { $_.Trim() -ne "" }
}

if (!$jobIds -or $jobIds.Count -eq 0) {
  Write-Host "未发现 RUNNING 的 Job。"
  exit 0
}

Write-Host "发现 JobID: $($jobIds -join ', ')"
foreach ($jid in $jobIds) {
  Write-Host "对 $jid 执行 savepoint 并优雅停止 ..."
  $cmdStop = "/opt/flink/bin/flink stop --drain --savepointPath $SavepointDir $jid"
  docker exec -i $JobManager sh -lc $cmdStop
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "停止 $jid 失败，请查看 JobManager 日志。"
  }
}

Write-Host "全部完成。保存点目录挂载在宿主机 infra/flink/data/savepoints 下。"