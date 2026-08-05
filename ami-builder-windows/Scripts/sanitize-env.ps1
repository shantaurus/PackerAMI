Write-Host "Sanitizing System Environment Variables..." -ForegroundColor Green

# Sanitize PATH
$rawPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
if ($rawPath) {
    $cleanPathEntries = $rawPath -split ';' | ForEach-Object {
        $entry = $_.Trim()
        $entry = $entry -replace '\\+$', ''
        $entry = $entry -replace '"', ''
        if (-not ($entry -match '^\\\\')) { $entry = $entry -replace '\\+', '\' }
        $entry
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    $sanitizedPath = $cleanPathEntries -join ';'
    if ($sanitizedPath.Length -gt 2048) {
        Write-Error "CRITICAL: System PATH exceeds 2048 characters."
        exit 1
    }
    [Environment]::SetEnvironmentVariable("Path", $sanitizedPath, [EnvironmentVariableTarget]::Machine)
}

# Sanitize PSModulePath
$rawPSModulePath = [Environment]::GetEnvironmentVariable("PSModulePath", [EnvironmentVariableTarget]::Machine)
if ($rawPSModulePath) {
    $cleanPSModuleEntries = $rawPSModulePath -split ';' | ForEach-Object {
        $entry = $_.Trim()
        $entry = $entry -replace '\\+$', ''
        $entry = $entry -replace '"', ''
        if (-not ($entry -match '^\\\\')) { $entry = $entry -replace '\\+', '\' }
        $entry
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    $sanitizedPSModulePath = $cleanPSModuleEntries -join ';'
    [Environment]::SetEnvironmentVariable("PSModulePath", $sanitizedPSModulePath, [EnvironmentVariableTarget]::Machine)
}