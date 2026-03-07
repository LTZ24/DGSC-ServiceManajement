@echo off
echo === Killing old Gradle daemons ===
cd /d C:\xampp\htdocs\DGSC\dgsc_mobile\android
call gradlew.bat --stop 2>&1
echo === Gradle stop exit: %ERRORLEVEL% ===

echo === Running Gradle assembleDebug directly ===
call gradlew.bat assembleDebug --stacktrace 2>&1
echo === Gradle build exit: %ERRORLEVEL% ===

echo === Checking APK ===
dir /s /b ..\build\app\outputs\*.apk 2>&1
echo === DONE ===
