@echo off
chcp 65001 >nul
setlocal EnableExtensions
title Aplicaciones Moviles - instalar y verificar
echo ============================================================
echo  Instala Git, Node.js y Flutter (si faltan), descarga los 6
echo  proyectos y los compila/analiza. Al final abre reporte.txt
echo ============================================================

rem ---------- 1) Herramientas ----------
set "PATH=%PATH%;C:\Program Files\Git\cmd;C:\Program Files\nodejs;C:\flutter\bin"

where git >nul 2>nul || (
  echo [1/3] Instalando Git...
  winget install -e --id Git.Git --accept-source-agreements --accept-package-agreements
)
where node >nul 2>nul || (
  echo [2/3] Instalando Node.js LTS...
  winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
)
where flutter >nul 2>nul || (
  echo [3/3] Instalando Flutter en C:\flutter ...
  if not exist C:\flutter git clone -b stable --depth 1 https://github.com/flutter/flutter.git C:\flutter
  powershell -NoProfile -Command "$p=[Environment]::GetEnvironmentVariable('Path','User'); if($p -notlike '*C:\flutter\bin*'){[Environment]::SetEnvironmentVariable('Path',$p+';C:\flutter\bin','User')}"
)
call flutter --version

rem ---------- 2) Proyectos ----------
cd /d "%USERPROFILE%\Documents"
if exist aplicaciones-moviles-grupo-k (
  cd aplicaciones-moviles-grupo-k
  git pull
) else (
  git clone https://github.com/Zemogg369pro/aplicaciones-moviles-grupo-k
  cd aplicaciones-moviles-grupo-k
)
set "LOG=%CD%\reporte.txt"
echo Reporte de verificacion %DATE% %TIME% > "%LOG%"

call :flutterProj 01-reservaciones\flutter-getx reservaciones_getx
call :flutterProj 02-camara-deteccion camara_deteccion
call :flutterProj 03-gps-bluetooth-sensores recorridos_ble
call :flutterProj 04-oauth-push objetos_perdidos
call :flutterProj 05-offline-sync\app incidencias_offline
call :flutterProj 06-websocket-deeplink\app chat_realtime

call :nodeProj 01-reservaciones\backend
call :nodeProj 05-offline-sync\backend
call :nodeProj 06-websocket-deeplink\backend
call :nodeProj 04-oauth-push\functions

echo.>> "%LOG%"
echo ===== Expo (BLoC) =====>> "%LOG%"
pushd 01-reservaciones\expo-bloc
call npm install --no-audit --no-fund >> "%LOG%" 2>&1 && echo OK npm install expo >> "%LOG%"
popd

echo.
echo LISTO. Abriendo reporte.txt ...
start notepad "%LOG%"
pause
exit /b

:flutterProj
echo.>> "%LOG%"
echo ===== %1 =====>> "%LOG%"
echo Verificando %1 ...
pushd %1
if not exist android call flutter create . --project-name %2 --org com.example --platforms=android,ios >> "%LOG%" 2>&1
if exist test\widget_test.dart del /q test\widget_test.dart
call flutter pub get >> "%LOG%" 2>&1
call flutter analyze --no-fatal-infos --no-fatal-warnings >> "%LOG%" 2>&1
popd
exit /b

:nodeProj
echo.>> "%LOG%"
echo ===== %1 =====>> "%LOG%"
echo Instalando %1 ...
pushd %1
call npm install --no-audit --no-fund >> "%LOG%" 2>&1
for %%F in (*.js) do node --check %%F >> "%LOG%" 2>&1 && echo OK sintaxis %%F >> "%LOG%"
popd
exit /b
