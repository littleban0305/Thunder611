$ErrorActionPreference = 'Stop'
Write-Host 'Thunder611 mobile platform setup' -ForegroundColor Cyan
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host '找不到 Flutter。請先安裝 Flutter SDK。' -ForegroundColor Yellow
  exit 1
}

flutter create --platforms=android,ios .

$androidManifest = Join-Path (Get-Location) 'android\app\src\main\AndroidManifest.xml'
if (Test-Path $androidManifest) {
  $xml = Get-Content $androidManifest -Raw
  if ($xml -notmatch 'android.permission.RECORD_AUDIO') {
    $xml = $xml -replace '(?s)(<manifest[^>]*>)', '$1`r`n    <uses-permission android:name="android.permission.RECORD_AUDIO" />'
    Set-Content -Path $androidManifest -Value $xml -Encoding UTF8
  }
}

$plist = Join-Path (Get-Location) 'ios\Runner\Info.plist'
if (Test-Path $plist) {
  $plistText = Get-Content $plist -Raw
  if ($plistText -notmatch 'NSMicrophoneUsageDescription') {
    $plistText = $plistText -replace '(?s)(</dict>)', '    <key>NSMicrophoneUsageDescription</key>\r\n    <string>雷霆611需要麥克風來使用語音房。</string>\r\n$1'
    Set-Content -Path $plist -Value $plistText -Encoding UTF8
  }
}

Write-Host 'Android / iOS 平台已建立，麥克風權限也已補上。' -ForegroundColor Green
Write-Host ''
Write-Host '接著執行：' -ForegroundColor Cyan
Write-Host '  flutter pub get'
Write-Host '  flutter analyze'
Write-Host '  flutter run -d android'
