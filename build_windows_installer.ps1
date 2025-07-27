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
Write-Host "Step 4: Creating Windows Installer..." -ForegroundColor Yellow
dart run msix_config.dart

Write-Host ""
Write-Host "Step 5: Installer created successfully!" -ForegroundColor Green
Write-Host "Location: build/windows/installer/" -ForegroundColor Cyan

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Read-Host "Press Enter to continue" 