@echo off
REM 一键同步本地改动到 GitHub（无需 WorkBuddy）
REM 首次使用：把 GitHub 令牌写进同目录的 .ghtoken 文件（一行），双击本文件即可。
setlocal
set "DIR=%~dp0"
if exist "%DIR%.ghtoken" (
  set /p GH_TOKEN=<"%DIR%.ghtoken"
)
if "%GH_TOKEN%"=="" (
  echo 未找到令牌。请把 GitHub 令牌写入 .ghtoken 文件（一行），或先设置 GH_TOKEN 环境变量。
  pause
  exit /b 1
)
bash "%DIR%sync_to_github.sh"
endlocal
