@echo off
echo Starting WordPress Multisite Manager...

:: Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo =========================================================
    echo ERROR: Python 3 is not installed or not in your PATH.
    echo Please install Python 3 (with PATH enabled) to run this GUI.
    echo =========================================================
    echo.
    pause
    exit /b 1
)

:: Open browser after a brief delay
start http://localhost:8000

:: Start python manager server
python manager.py
