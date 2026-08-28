$envFile = Join-Path $PSScriptRoot ".env"

if (-not (Test-Path $envFile)) {
    Write-Host "找不到 .env，請先建立 .env" -ForegroundColor Yellow
    Write-Host "格式：THUNDER611_GIPHY_KEY=你的GIPHY_API_KEY"
    exit 1
}

$line = Get-Content $envFile |
    Where-Object { $_ -match '^THUNDER611_GIPHY_KEY=' } |
    Select-Object -First 1

$key = if ($line) {
    $line.Substring('THUNDER611_GIPHY_KEY='.Length).Trim()
} else {
    ''
}

if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Host "找不到 THUNDER611_GIPHY_KEY" -ForegroundColor Yellow
    exit 1
}

Write-Host "Starting Thunder611..." -ForegroundColor Cyan

flutter run `
    --dart-define="THUNDER611_GIPHY_KEY=$key"