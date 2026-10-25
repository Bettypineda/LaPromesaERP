@echo off
chcp 65001 >nul
cd /d "%~dp0"
title La Promesa ERP - Frontend
where node >nul 2>nul || (echo Node.js no esta instalado. Descarguelo de https://nodejs.org & pause & exit /b 1)
if not exist node_modules (
  echo Instalando dependencias por primera vez...
  call npm install || (pause & exit /b 1)
)
echo Iniciando el frontend en http://localhost:5173 ...
call npm run dev
pause
