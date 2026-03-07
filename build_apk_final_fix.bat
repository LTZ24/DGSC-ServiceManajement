@echo off
echo === Setting PUB_CACHE to space-free path ===
set PUB_CACHE=C:\PubCache
mkdir C:\PubCache 2>nul

echo === Using Junction for Flutter SDK ===
set FLUTTER_CMD=C:\flutter\bin\flutter.bat
if not exist "C:\flutter\bin\flutter.bat" (
    echo Junction C:\flutter not found. Using default flutter...
    set FLUTTER_CMD=flutter
)

echo === Cleaning Workspace ===
cd /d C:\xampp\htdocs\DGSC\dgsc_mobile
call %FLUTTER_CMD% clean 2>&1

echo === Getting Dependencies (to new cache) ===
call %FLUTTER_CMD% pub get 2>&1

echo === Building Debug APK ===
call %FLUTTER_CMD% build apk --debug 2>&1

echo === Build Exit Code: %ERRORLEVEL% ===
echo === Checking APK output ===
dir /s /b build\app\outputs\*.apk 2>&1
echo === DONE ===
