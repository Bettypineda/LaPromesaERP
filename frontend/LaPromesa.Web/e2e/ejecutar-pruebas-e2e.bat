@echo off
chcp 65001 >nul
cd /d "%~dp0\.."
title La Promesa ERP - Pruebas E2E y capturas
echo Requisitos: API (5000), banco simulado (5100) y frontend (5173) encendidos.
if not exist node_modules\playwright-core (
  echo Instalando playwright-core...
  call npm install --save-dev playwright-core@1.56.1 || (pause & exit /b 1)
)
node e2e\capturas.mjs > e2e\ultima-ejecucion.log 2>&1
type e2e\ultima-ejecucion.log
echo.
echo Listo. Revise docs\evidencias\capturas
pause
