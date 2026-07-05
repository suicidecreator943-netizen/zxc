$sourceFile  = "C:\ProgramData\NVIDIA Corporation\Drs\nvAppTimestamps"
$outputDir   = "C:\paths"
$outputFile  = Join-Path $outputDir "p.txt"
$exeFile     = Join-Path $outputDir "PathsParser.exe"
$downloadUrl = "https://github.com/spokwn/PathsParser/releases/download/v1.2/PathsParser.exe"

$cleanup = {
    $filesToClean = @("p.txt", "replaces.txt", "PathsParser.txt", "PathsParser.exe")
    foreach ($file in $filesToClean) {
        $target = Join-Path "C:\paths" $file
        if (Test-Path $target) {
            Remove-Item $target -Force -ErrorAction SilentlyContinue
        }
    }
}

[System.AppDomain]::CurrentDomain.add_ProcessExit({ & $cleanup })

if (-not (Test-Path $sourceFile)) { return }

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

if (Test-Path $exeFile) {
    if ((Get-Item $exeFile).Length -lt 10000) {
        Remove-Item $exeFile -Force | Out-Null
    }
}

if (-not (Test-Path $exeFile)) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $oldProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $exeFile -ErrorAction SilentlyContinue
        $ProgressPreference = $oldProgressPreference
    } catch { return }
}

try {
    $fileBytes = [System.IO.File]::ReadAllBytes($sourceFile)
    $rawText = [System.Text.Encoding]::Unicode.GetString($fileBytes)
    $sanitizedText = $rawText -replace "`0", " "

    $pattern = '[a-zA-Z]:\/[^`"\?\*<>\|]+?\.[a-zA-Z0-9]{1,5}'


    $cleanedPaths = [regex]::Matches($sanitizedText, $pattern) | 
        ForEach-Object { $_.Value } | 
        ForEach-Object {
            $path = $_
            $path = $path -replace '[^\x20-\x7E\x80-\xFFА-Яа-яёЁ\/]', ''
            $path = $path -replace '/', '\'
            $path.Trim()
        } | 
        Where-Object { $_ -match '^[a-zA-Z]:\\' } | 
        Select-Object -Unique

    if ($cleanedPaths) {
        [System.IO.File]::WriteAllLines($outputFile, $cleanedPaths, [System.Text.Encoding]::UTF8)
    } else {
        $null | Out-File -FilePath $outputFile -Encoding utf8
    }
} catch { return }

if (Test-Path $exeFile) {
    if ((Get-Item $exeFile).Length -ge 10000) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $exeFile
        $psi.WorkingDirectory       = $outputDir
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardInput  = $true
        $psi.RedirectStandardOutput = $false

        $process = [System.Diagnostics.Process]::Start($psi)

        if ($process) {
            try {
                $process.StandardInput.WriteLine("y")
                Start-Sleep -Milliseconds 300
                $process.StandardInput.WriteLine("n")
                Start-Sleep -Milliseconds 300
                $process.StandardInput.WriteLine("y")
                Start-Sleep -Milliseconds 300
                $process.StandardInput.WriteLine("n")

                $process.WaitForExit()
            }
            finally {
                if (-not $process.HasExited) {
                    $process.Kill()
                }
                & $cleanup
            }
        }
    }
}
