@echo off
title SalesArmy Web Admin - Live Deploy & Public Tunnel
echo ============================================================
echo   SalesArmy Super Admin Portal - Instant Live Deployment
echo ============================================================
echo.
cd /d "%~dp0"
node scripts\start-live.js
pause

