@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Anne-Neri L4D2 Server (Windows Server 2022)

rem =====================================================================
rem  Anne-Neri 药役专用服 —— Windows Server 2022 启动脚本
rem  放置位置：left4dead2 目录内（与 addons / cfg 同级）
rem  默认调用上一级目录的 srcds.exe；如服务端布局不同，修改下面的 SRCDS 变量
rem  功能：带自动重启循环，等价于 Linux 下 srcds_run 的看护循环
rem =====================================================================

set "SRCDIR=%~dp0.."
set "SRCDS=%SRCDIR%\srcds.exe"

rem ---------------- 可按需修改的启动参数 ----------------
set "PORT=27015"
set "TICKRATE=100"
set "STARTMAP=c1m1_hotel"
rem 公网服务器请填写游戏服务器登录令牌(GSLT)，内网/局域网可留空
set "GSLT="
rem -----------------------------------------------------

if not exist "%SRCDS%" (
  echo [ERROR] 未找到 srcds.exe : %SRCDS%
  echo         请把本脚本放在 left4dead2 目录内，或修改脚本中的 SRCDS 变量。
  pause
  exit /b 1
)

set "GSLTARG="
if not "%GSLT%"=="" set "GSLTARG=+sv_setsteamaccount %GSLT%"

echo ============================================================
echo  服务端根目录 : %SRCDIR%
echo  启动地图     : %STARTMAP%
echo  端口         : %PORT%
echo  Tickrate     : %TICKRATE%  (由 addons/tickrate_enabler.dll 解锁)
echo  GSLT         : %GSLT%
echo ============================================================

:loop
echo [%date% %time%] starting srcds.exe ...
"%SRCDS%" -game left4dead2 -console -condebug -norestart ^
  -ip 0.0.0.0 -port %PORT% -tickrate %TICKRATE% ^
  +sv_lan 0 +exec server.cfg +exec windows_override.cfg %GSLTARG% +map %STARTMAP%

echo [%date% %time%] srcds.exe 已退出 (code=%errorlevel%)，10 秒后自动重启 ...
timeout /t 10 /nobreak >nul
goto loop
