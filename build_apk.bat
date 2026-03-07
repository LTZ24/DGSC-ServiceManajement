@echo off
cd /d C:\xampp\htdocs\DGSC\dgsc_mobile
echo === DGSC Mobile APK Build ===
echo.

:: Option 1 — Split APKs per ABI (smallest, for direct install / Play Store)
echo [1] Building split APKs (per-ABI, smallest size)...
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug_info 2>&1
echo === Split APK Build Exit Code: %ERRORLEVEL% ===
echo Output: build\app\outputs\flutter-apk\
echo   app-arm64-v8a-release.apk   (64-bit devices, recommended)
echo   app-armeabi-v7a-release.apk (32-bit older devices)
echo   app-x86_64-release.apk      (emulators)
echo.

:: Option 2 — Universal single APK (larger, for sharing)
:: echo [2] Building universal APK...
:: flutter build apk --release --obfuscate --split-debug-info=build/debug_info 2>&1

echo === Done ===
pause
