@echo off
echo === Downloading JDK 17 (Eclipse Temurin) ===
mkdir C:\jdk17 2>nul
cd /d C:\jdk17

REM Download JDK 17 from Adoptium
powershell -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk' -OutFile 'jdk17.zip' -UseBasicParsing }"
echo Download exit code: %ERRORLEVEL%

REM Check size
dir jdk17.zip

REM Extract
echo === Extracting JDK 17 ===
powershell -Command "Expand-Archive -Path 'C:\jdk17\jdk17.zip' -DestinationPath 'C:\jdk17' -Force"
echo Extract exit code: %ERRORLEVEL%

REM List contents
dir C:\jdk17

REM Find java.exe
echo === Finding java.exe ===
dir /s /b C:\jdk17\*java.exe 2>&1 | findstr /i "bin\\java.exe"

echo === DONE ===
