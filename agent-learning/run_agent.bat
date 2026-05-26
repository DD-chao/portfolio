@echo off
chcp 65001 >nul 2>&1
cd /d D:\agent-learning
cls
echo Dify Agent - CLI Tool
echo Type your question, or "quit" to exit.
echo.

:loop
set /p q=">> "
if "%q%"=="" goto loop
if /i "%q%"=="quit" exit /b
echo.
python agent_cli.py "%q%"
echo.
goto loop
