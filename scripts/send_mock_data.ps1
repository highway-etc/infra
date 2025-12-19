Param(
  [int]$N = 100,
  [string]$Broker = 'kafka:9092',
  [string]$Topic = 'etc_traffic',
  [string]$KafkaContainer = 'kafka',
  [string]$DataDir = './flink/data/test_data'
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host 'Sending $N real records from $DataDir to Kafka, broker=$Broker, topic=$Topic ...'

# Æô¶¯ kafka-console-producer ½ø³Ì
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = 'docker'
$psi.ArgumentList.Add('exec')
$psi.ArgumentList.Add('-i')
$psi.ArgumentList.Add($KafkaContainer)
$psi.ArgumentList.Add('bash')
$psi.ArgumentList.Add('-lc')
$psi.ArgumentList.Add('kafka-console-producer --bootstrap-server "' + $Broker + '" --topic "' + $Topic + '" --producer-property acks=all --producer-property linger.ms=10')
$psi.RedirectStandardInput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false

$p = [System.Diagnostics.Process]::Start($psi)
$stdin = $p.StandardInput

try {
    $files = Get-ChildItem -Path $DataDir -Filter '*.csv' | Sort-Object Name
    $emitted = 0
    
    foreach ($f in $files) {
        if ($N -gt 0 -and $emitted -ge $N) { break }
        
        $records = Import-Csv -Path $f.FullName
        foreach ($row in $records) {
            if ($N -gt 0 -and $emitted -ge $N) { break }
            
            $gcxh = $row.'GCXH'
            $xzqhmc = $row.'XZQHMC'
            $kkmc = $row.'KKMC'
            $fxlxCode = $row.'FXLX'
            $gcsjRaw = $row.'GCSJ'
            $hpzl = $row.'HPZL'
            
            $hphm = $row.'HPHM'
            if (-not $hphm) { $hphm = $row.'SUBSTR(HPHM,1,4)||''***''' }
            if (-not $hphm) { $hphm = 'Unknown' }
            
            $hphmMask = if ($hphm.Length -gt 4) { $hphm.Substring(0, 4) + '***' } else { $hphm + '***' }
            
            $clppxh = $row.'CLPPXH'

            $fxlx = switch ($fxlxCode) { '1' { 'IN' } '2' { 'OUT' } default { 'IN' } }
            
            try {
                $gcsj = ([datetime]::Parse($gcsjRaw)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            } catch {
                $gcsj = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            }

            $stationId = 100 + ([math]::Abs($kkmc.GetHashCode()) % 10)
            
            $jsonObj = @{ 
                gcxh = $gcxh; 
                xzqhmc = $xzqhmc; 
                adcode = 330100; 
                kkmc = $kkmc; 
                station_id = $stationId; 
                fxlx = $fxlx; 
                gcsj = $gcsj; 
                hpzl = $hpzl; 
                hphm = $hphmMask; 
                hphm_mask = $hphmMask; 
                clppxh = $clppxh 
            }
            
            $json = $jsonObj | ConvertTo-Json -Compress
            
            $stdin.WriteLine($json)
            $emitted++
            
            if ($emitted % 50 -eq 0) {
                Write-Host 'Sent $emitted records...'
                Start-Sleep -Milliseconds 100
            }
        }
    }
}
finally {
    $stdin.Close()
    $p.WaitForExit()
    $p.Close()
}

Write-Host 'Done. Total emitted: $emitted'
