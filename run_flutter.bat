@echo off
set PATH=C:\Program Files\Git\bin;%PATH%
set FLUTTER_ROOT=C:\src\flutter
set PATH=%FLUTTER_ROOT%\bin;%PATH%

echo Git version:
git --version

echo.
echo Flutter version:
flutter --version

echo.
echo Running flutter analyze...
flutter analyze

pause 