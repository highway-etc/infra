Param(
  [string]$Tag = 'latest',
  [switch]$SkipBuild,
  [switch]$SkipFlinkSubmit,
  [int]$IngestChunkSize = 2000,
  [int]$IngestPauseMs = 800,
  [int]$IngestMaxTotal = 0
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Console]::InputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

# BlueCat one-click start: build backend and frontend images -> bring up infrastructure -> submit Flink jobs -> run backend and frontend containers
$infraDir = Split-Path $PSScriptRoot -Parent
$rootDir = Split-Path $infraDir -Parent
$servicesDir = Join-Path $rootDir 'services'
$frontendDir = Join-Path $rootDir 'frontend'
$network = 'infra_etcnet'

Write-Host "[BlueCat] one-click start image-tag: $Tag" -ForegroundColor Cyan

if (-not $SkipBuild) {
  Write-Host '[BlueCat] build backend image bluecat/etc-services' -ForegroundColor Yellow
  docker build -t "bluecat/etc-services:$Tag" $servicesDir
  if ($LASTEXITCODE -ne 0) { throw "build etc-services failed" }

  Write-Host '[BlueCat] build frontend image bluecat/etc-frontend' -ForegroundColor Yellow
  docker build -t "bluecat/etc-frontend:$Tag" $frontendDir
  if ($LASTEXITCODE -ne 0) { throw "build etc-frontend failed" }
} else {
  Write-Host '[BlueCat] skip image build' -ForegroundColor DarkYellow
}

Push-Location $infraDir
try {
  Write-Host '[BlueCat] up infrastructure docker-compose.dev.yml' -ForegroundColor Yellow
  docker compose -f docker-compose.dev.yml up -d
  if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

  # wait mysql healthy
  Write-Host '[BlueCat] waiting mysql healthy...' -ForegroundColor Yellow
  for ($i = 0; $i -lt 40; $i++) {
    $status = docker inspect -f '{{.State.Health.Status}}' mysql 2>$null
    if ($status -eq 'healthy') { break }
    Start-Sleep -Seconds 3
  }

  # wait mycat up (container running + grace period)
  Write-Host '[BlueCat] waiting mycat to settle...' -ForegroundColor Yellow
  for ($i = 0; $i -lt 10; $i++) {
    $state = docker inspect -f '{{.State.Running}}' mycat 2>$null
    if ($state -eq 'true') { break }
    Start-Sleep -Seconds 2
  }
  Start-Sleep -Seconds 5

  # Optional: submit Flink jobs
  if (-not $SkipFlinkSubmit) {
    Write-Host '[BlueCat] submit Flink jobs TrafficStreamingJob / PlateCloneDetectionJob' -ForegroundColor Yellow
    docker exec flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.TrafficStreamingJob /opt/flink/usrlib/streaming-0.1.0.jar
    docker exec flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.PlateCloneDetectionJob /opt/flink/usrlib/streaming-0.1.0.jar
  } else {
    Write-Host '[BlueCat] skip Flink submit' -ForegroundColor DarkYellow
  }

  # run backend container
  Write-Host '[BlueCat] run etc-services container (8080)' -ForegroundColor Yellow
  $svcExists = (docker ps -aq --filter "name=etc-services")
  if ($svcExists) { docker rm -f etc-services | Out-Null }
  docker run -d --name etc-services --network $network -p 8080:8080 "bluecat/etc-services:$Tag"

  # run frontend container
  Write-Host '[BlueCat] run etc-frontend container (8088)' -ForegroundColor Yellow
  $feExists = (docker ps -aq --filter "name=etc-frontend")
  if ($feExists) { docker rm -f etc-frontend | Out-Null }
  docker run -d --name etc-frontend --network $network -p 8088:80 "bluecat/etc-frontend:$Tag"
  
  # Automatically send data in batches to avoid exploding Flink at once
  Write-Host "[BlueCat] batch-push CSV to Kafka (chunk=$IngestChunkSize pauseMs=$IngestPauseMs max=$IngestMaxTotal)" -ForegroundColor Yellow
  powershell -ExecutionPolicy ByPass -File (Join-Path $infraDir 'scripts/send_csv_batch.ps1') -Broker 'kafka:9092' -Topic 'etc_traffic' -DataDir (Join-Path $infraDir 'flink/data/test_data') -Network $network -ChunkSize $IngestChunkSize -PauseMs $IngestPauseMs -MaxTotal $IngestMaxTotal
}
finally {
  Pop-Location
}

Write-Host '[BlueCat] all done, frontend: http://localhost:8088 backend: http://localhost:8080/swagger-ui.html' -ForegroundColor Green
