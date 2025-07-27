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
echo Step 4: Creating Windows Installer with Inno Setup...
cd installer
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" jamaat_time_setup.iss
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    "C:\Program Files\Inno Setup 6\ISCC.exe" jamaat_time_setup.iss
) else (
    echo ERROR: Inno Setup not found!
    echo Please install Inno Setup 6 from: https://jrsoftware.org/isdl.php
    echo Or download the portable version and place ISCC.exe in the project root
    cd ..
    pause
    exit /b 1
)
cd ..

echo.
echo Step 5: Installer created successfully!
echo Location: build/windows/installer/JamaatTime_Setup_v1.0.12.exe
echo.
echo ========================================
echo Build Complete!
echo ========================================
pause 