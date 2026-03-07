@echo off
cd /d C:\xampp\htdocs\DGSC\dgsc_mobile
echo === JAVA_HOME: %JAVA_HOME% ===
java -version 2>&1
echo === Cleaning previous build ===
call flutter clean 2>&1
echo === Getting dependencies ===
call flutter pub get 2>&1
echo === Building Debug APK ===
call flutter build apk --debug 2>&1
echo === Build Exit Code: %ERRORLEVEL% ===
echo === Checking APK output ===
dir /s /b build\app\outputs\*.apk 2>&1
echo === DONE ===
