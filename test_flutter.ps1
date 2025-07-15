# PowerShell script to test Flutter with correct Git PATH
Write-Host "Setting up PATH for Flutter..." -ForegroundColor Green

# Add Git to PATH
$env:PATH = "C:\Program Files\Git\bin;$env:PATH"
$env:FLUTTER_ROOT = "C:\src\flutter"
$env:PATH = "$env:FLUTTER_ROOT\bin;$env:PATH"

Write-Host "`nTesting Git:" -ForegroundColor Yellow
git --version

Write-Host "`nTesting Flutter:" -ForegroundColor Yellow
flutter --version

Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
flutter analyze

Write-Host "`nPress any key to continue..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 