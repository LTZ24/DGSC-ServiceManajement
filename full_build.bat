@echo off
echo === Step 1: pub get ===
cd /d C:\xampp\htdocs\DGSC\dgsc_mobile
call flutter pub get 2>&1
echo === pub get exit: %ERRORLEVEL% ===

echo === Step 2: Stop old Gradle daemons ===
cd /d C:\xampp\htdocs\DGSC\dgsc_mobile\android
call gradlew.bat --stop 2>&1
echo === Gradle stop exit: %ERRORLEVEL% ===

echo === Step 3: Run Gradle assembleDebug ===
call gradlew.bat assembleDebug --stacktrace --no-daemon 2>&1
echo === Gradle build exit: %ERRORLEVEL% ===

echo === Step 4: Check APK ===
dir /s /b C:\xampp\htdocs\DGSC\dgsc_mobile\build\app\outputs\*.apk 2>&1
echo === ALL DONE ===
