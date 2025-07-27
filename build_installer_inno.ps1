Write-Host "========================================" -ForegroundColor Green
Write-Host "Building Jamaat Time Windows Installer" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host ""
Write-Host "Step 1: Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

Write-Host ""
Write-Host "Step 2: Getting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host ""
Write-Host "Step 3: Building Windows Release..." -ForegroundColor Yellow
flutter build windows --release

Write-Host ""
Write-Host "Step 4: Creating Windows Installer with Inno Setup..." -ForegroundColor Yellow

$innoSetupPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)

$innoSetupFound = $false
foreach ($path in $innoSetupPaths) {
    if (Test-Path $path) {
        Write-Host "Found Inno Setup at: $path" -ForegroundColor Green
        Push-Location "installer"
        & $path "jamaat_time_setup.iss"
        Pop-Location
        $innoSetupFound = $true
        break
    }
}

if (-not $innoSetupFound) {
    Write-Host "ERROR: Inno Setup not found!" -ForegroundColor Red
    Write-Host "Please install Inno Setup 6 from: https://jrsoftware.org/isdl.php" -ForegroundColor Yellow
    Write-Host "Or download the portable version and place ISCC.exe in the project root" -ForegroundColor Yellow
    Read-Host "Press Enter to continue"
    exit 1
}

Write-Host ""
Write-Host "Step 5: Installer created successfully!" -ForegroundColor Green
Write-Host "Location: build/windows/installer/JamaatTime_Setup_v1.0.12.exe" -ForegroundColor Cyan

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Read-Host "Press Enter to continue" 