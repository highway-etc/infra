Param(
    [string]$Tag = 'latest',
    [switch]$SkipBuild,
    [switch]$SkipFlinkSubmit,
    [int]$IngestChunkSize = 500,
    [int]$IngestPauseMs = 1200,
    # 0 means unlimited
    [int]$IngestMaxTotal = 5000,
    [switch]$SkipStream,
    [int]$StreamRate = 60,
    [double]$StreamCloneRate = 0.02,
    [string]$StreamFocusPrefix = 'SU'
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Console]::InputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

# BlueCat one-click start: build backend/frontend images -> infra up -> submit Flink -> run backend/frontend -> seed data
$infraDir = Split-Path -Parent $PSScriptRoot
$rootDir = Split-Path -Parent $infraDir
$servicesDir = Join-Path $rootDir 'services'
$frontendDir = Join-Path $rootDir 'frontend'
$network = 'infra_etcnet'
$kafkaBroker = 'localhost:29092'
$kafkaTopic = 'etc_traffic'

function Stop-FlinkJobIfExists {
    param(
        [string]$JobName
    )

    # Flink prints a JDK warning on stderr; wrap in cmd /c to merge streams and avoid NativeCommandError
    $listOutput = cmd /c "docker exec flink-jobmanager /opt/flink/bin/flink list 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "[BlueCat] failed to list Flink jobs before canceling $JobName"
        Write-Warning ($listOutput -join "`n")
        return
    }

    $lines = $listOutput | Where-Object { $_ -notmatch '^WARNING:' }
    $text = $lines -join "`n"

    $pattern = 'JobId\s*:\s*(?<id>[A-Za-z0-9\-]+)\s*,\s*Name\s*:\s*(?<name>[^,]+)'
    $matches = [regex]::Matches($text, $pattern)
    $found = $false
    foreach ($m in $matches) {
        $name = $m.Groups['name'].Value.Trim()
        if ($name -eq $JobName) {
            $found = $true
            $jobId = $m.Groups['id'].Value.Trim()
            Write-Host "[BlueCat] cancel existing Flink job $JobName ($jobId)" -ForegroundColor Yellow
            docker exec flink-jobmanager /opt/flink/bin/flink cancel $jobId | Out-Null
        }
    }

    if (-not $found) {
        Write-Host "[BlueCat] no running Flink job named $JobName" -ForegroundColor DarkGray
    }
}

Write-Host "[BlueCat] one-click start image-tag: $Tag" -ForegroundColor Cyan

if (-not $SkipBuild) {
    Write-Host "[BlueCat] build backend image etc-services" -ForegroundColor Yellow
    docker build -t "etc-services:$Tag" $servicesDir
    if ($LASTEXITCODE -ne 0) { throw "build etc-services failed" }

    Write-Host "[BlueCat] build frontend image etc-frontend" -ForegroundColor Yellow
    docker build -t "etc-frontend:$Tag" $frontendDir
    if ($LASTEXITCODE -ne 0) { throw "build etc-frontend failed" }
} else {
    Write-Host "[BlueCat] skip image build" -ForegroundColor DarkYellow
}

Push-Location $infraDir
try {
    Write-Host "[BlueCat] up infrastructure docker-compose.dev.yml" -ForegroundColor Yellow
    docker compose -f docker-compose.dev.yml up -d
    if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

    Write-Host "[BlueCat] waiting mysql healthy..." -ForegroundColor Yellow
    for ($i = 0; $i -lt 40; $i++) {
        $status = docker inspect -f '{{.State.Health.Status}}' mysql 2>$null
        if ($status -eq 'healthy') { break }
        Start-Sleep -Seconds 3
    }

    Write-Host "[BlueCat] waiting mycat to settle..." -ForegroundColor Yellow
    for ($i = 0; $i -lt 10; $i++) {
        $state = docker inspect -f '{{.State.Running}}' mycat 2>$null
        if ($state -eq 'true') { break }
        Start-Sleep -Seconds 2
    }
    Start-Sleep -Seconds 5

    if (-not $SkipFlinkSubmit) {
        Stop-FlinkJobIfExists 'TrafficStreamingJob'
        Stop-FlinkJobIfExists 'PlateCloneDetectionJob'
        Start-Sleep -Seconds 2
        Write-Host "[BlueCat] submit Flink jobs TrafficStreamingJob / PlateCloneDetectionJob" -ForegroundColor Yellow
        docker exec flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.TrafficStreamingJob /opt/flink/usrlib/streaming-0.1.0.jar
        docker exec flink-jobmanager /opt/flink/bin/flink run -d -c com.highway.etc.job.PlateCloneDetectionJob /opt/flink/usrlib/streaming-0.1.0.jar
    } else {
        Write-Host "[BlueCat] skip Flink submit" -ForegroundColor DarkYellow
    }

    Write-Host "[BlueCat] run etc-services container (8080)" -ForegroundColor Yellow
    $svcExists = docker ps -aq --filter 'name=etc-services'
    if ($svcExists) { docker rm -f etc-services | Out-Null }
    docker run -d --name etc-services --network $network -p 8080:8080 "etc-services:$Tag"

    Write-Host "[BlueCat] run etc-frontend container (8088)" -ForegroundColor Yellow
    $feExists = docker ps -aq --filter 'name=etc-frontend'
    if ($feExists) { docker rm -f etc-frontend | Out-Null }
    docker run -d --name etc-frontend --network $network -p 8088:80 "etc-frontend:$Tag"

    if (-not $SkipStream) {
        $jobName = 'etc-mock-stream'
        $existingJob = Get-Job -Name $jobName -ErrorAction SilentlyContinue
        if ($existingJob) {
            Stop-Job -Job $existingJob -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Job -Job $existingJob -Force -ErrorAction SilentlyContinue | Out-Null
        }
        $streamScript = Join-Path $infraDir 'scripts/generate_mock_stream.py'
        Write-Host "[BlueCat] start continuous mock stream (rate=$StreamRate clone=$StreamCloneRate focus=$StreamFocusPrefix)" -ForegroundColor Yellow
        Start-Job -Name $jobName -ScriptBlock {
            param($scriptPath, $bootstrap, $topic, $rate, $clone, $focus)
            python $scriptPath --bootstrap $bootstrap --topic $topic --rate $rate --clone-rate $clone --focus-prefix $focus
        } -ArgumentList $streamScript, $kafkaBroker, $kafkaTopic, $StreamRate, $StreamCloneRate, $StreamFocusPrefix | Out-Null
    } else {
        Write-Host "[BlueCat] skip continuous mock stream" -ForegroundColor DarkYellow
    }

    Write-Host "[BlueCat] batch-push CSV to Kafka (chunk=$IngestChunkSize pauseMs=$IngestPauseMs max=$IngestMaxTotal)" -ForegroundColor Yellow
    # send_csv_batch.ps1 runs on host, uses localhost:29092
    powershell -ExecutionPolicy Bypass -File (Join-Path $infraDir 'scripts/send_csv_batch.ps1') -Broker $kafkaBroker -Topic $kafkaTopic -DataDir (Join-Path $infraDir 'flink/data/test_data') -Network $network -ChunkSize $IngestChunkSize -PauseMs $IngestPauseMs -MaxTotal $IngestMaxTotal
}
finally {
    Pop-Location
}

Write-Host "[BlueCat] all done, frontend: http://localhost:8088 backend: http://localhost:8080/swagger-ui.html" -ForegroundColor Green
