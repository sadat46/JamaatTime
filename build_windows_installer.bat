@echo off
echo ========================================
echo Building Jamaat Time Windows Installer
echo ========================================

echo.
echo Step 1: Cleaning previous builds...
flutter clean

echo.
echo Step 2: Getting dependencies...
flutter pub get

echo.
echo Step 3: Building Windows Release...
flutter build windows --release

echo.
echo Step 4: Creating Windows Installer...
dart run msix_config.dart

echo.
echo Step 5: Installer created successfully!
echo Location: build/windows/installer/
echo.
echo ========================================
echo Build Complete!
echo ========================================
pause 