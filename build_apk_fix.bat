@echo off
echo === Creating junction for Flutter SDK (removes spaces from path) ===

:: Remove old junction if exists
if exist C:\flutter (
    rmdir C:\flutter
)

:: Create junction: C:\flutter -> actual Flutter SDK path
mklink /J C:\flutter "C:\Users\Muhamad Latip M\develop\flutter"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to create junction. Try running as Administrator.
    exit /b 1
)

echo Junction created: C:\flutter

:: Verify
echo === Verifying Flutter via junction ===
C:\flutter\bin\flutter --version

echo === Cleaning ===
cd /d C:\xampp\htdocs\DGSC\dgsc_mobile
C:\flutter\bin\flutter clean

echo === Getting dependencies ===
C:\flutter\bin\flutter pub get

echo === Building Debug APK ===
C:\flutter\bin\flutter build apk --debug

echo === Build Exit Code: %ERRORLEVEL% ===
echo === Checking APK ===
dir /s /b build\app\outputs\*.apk 2>&1
echo === DONE ===
