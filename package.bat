@echo off
echo ===================================================
echo Windows Packaging Script for WordPress Docker Manager
echo ===================================================

:: Check for Python
python --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Python 3 must be installed and in your PATH.
    echo.
    pause
    exit /b 1
)

echo Setting up temporary Python virtual environment...
python -m venv build_venv
call build_venv\Scripts\activate.bat

echo Installing PyInstaller...
python -m pip install --upgrade pip
pip install pyinstaller

echo Compiling manager.py into a standalone EXE...
pyinstaller --onefile --noconsole --name "wp-manager" --add-data "manager_ui.html;." manager.py

call build_venv\Scripts\deactivate.bat
rmdir /s /q build_venv

echo ===================================================
echo Build Complete!
echo Standalone EXE located in: .\dist\wp-manager.exe
echo ===================================================
pause
