@echo off
chcp 65001 >nul
cd /d "%~dp0"
title La Promesa ERP - Frontend para celular
where node >nul 2>nul || (echo Node.js no esta instalado. & pause & exit /b 1)
if not exist node_modules call npm install
echo.
echo  Antes de seguir: Docker y la API en Visual Studio deben estar encendidos.
echo  El celular debe estar conectado al MISMO WiFi que esta computadora.
echo.
echo  Abra en el navegador del celular la direccion que aparece abajo como "Network":
echo  (si Windows pregunta por el Firewall, presione "Permitir")
echo.
call npm run dev -- --host --mode celular
pause
