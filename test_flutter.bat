@echo off
echo Setting up PATH for Flutter...
set PATH=C:\Program Files\Git\bin;%PATH%
set FLUTTER_ROOT=C:\src\flutter
set PATH=%FLUTTER_ROOT%\bin;%PATH%

echo.
echo Testing Git:
git --version

echo.
echo Testing Flutter:
flutter --version

echo.
echo If both commands work above, you can now run:
echo flutter analyze
echo flutter doctor
echo flutter pub get
echo.
pause 