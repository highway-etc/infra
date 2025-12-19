Param(
  [string]$Tag = 'latest',
  [switch]$SkipBuild,
  [switch]$SkipFlinkSubmit
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Console]::InputEncoding = [Text.Encoding]::UTF8

# BlueCat 一键启动：构建前后端镜像 -> 拉起基础设施 -> 提交 Flink 作业 -> 运行前后端容器
$infraDir = Split-Path $PSScriptRoot -Parent
$rootDir = Split-Path $infraDir -Parent
$servicesDir = Join-Path $rootDir 'services'
$frontendDir = Join-Path $rootDir 'frontend'
$network = 'infra_etcnet'

Write-Host "[BlueCat] 一键启动，镜像标签: $Tag" -ForegroundColor Cyan

if (-not $SkipBuild) {
  Write-Host '[BlueCat] 构建后端镜像 bluecat/etc-services' -ForegroundColor Yellow
  docker build -t "bluecat/etc-services:$Tag" $servicesDir

  Write-Host '[BlueCat] 构建前端镜像 bluecat/etc-frontend' -ForegroundColor Yellow
  docker build -t "bluecat/etc-frontend:$Tag" $frontendDir
} else {
  Write-Host '[BlueCat] 跳过镜像构建' -ForegroundColor DarkYellow
}

Push-Location $infraDir
try {
  Write-Host '[BlueCat] 拉起基础设施 docker-compose.dev.yml' -ForegroundColor Yellow
  docker compose -f docker-compose.dev.yml up -d

  # 可选：提交 Flink 作业
  if (-not $SkipFlinkSubmit) {
    Write-Host '[BlueCat] 提交 Flink 作业 TrafficStreamingJob / PlateCloneDetectionJob' -ForegroundColor Yellow
    docker exec flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.TrafficStreamingJob /opt/flink/usrlib/streaming-0.1.0.jar
    docker exec flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.PlateCloneDetectionJob /opt/flink/usrlib/streaming-0.1.0.jar
  } else {
    Write-Host '[BlueCat] 跳过 Flink 提交' -ForegroundColor DarkYellow
  }

  # 运行后端容器
  Write-Host '[BlueCat] 运行 etc-services 容器 (8080)' -ForegroundColor Yellow
  $svcExists = (docker ps -aq --filter "name=etc-services")
  if ($svcExists) { docker rm -f etc-services | Out-Null }
  docker run -d --name etc-services --network $network -p 8080:8080 "bluecat/etc-services:$Tag"

  # 运行前端容器
  Write-Host '[BlueCat] 运行 etc-frontend 容器 (8088)' -ForegroundColor Yellow
  $feExists = (docker ps -aq --filter "name=etc-frontend")
  if ($feExists) { docker rm -f etc-frontend | Out-Null }
  docker run -d --name etc-frontend --network $network -p 8088:80 "bluecat/etc-frontend:$Tag"
}
finally {
  Pop-Location
}

Write-Host '[BlueCat] 全部完成，前端: http://localhost:8088 后端: http://localhost:8080/swagger-ui.html' -ForegroundColor Green
