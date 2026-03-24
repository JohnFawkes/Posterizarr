@echo off
setlocal enabledelayedexpansion
echo.
echo 🚀 Posterizarr Web UI - Quick Setup
echo ====================================
echo.

REM Check if we're in the right directory
if not exist "..\Posterizarr.ps1" (
    echo ❌ Error: Posterizarr.ps1 not found in parent directory.
    echo Please run this script from the 'webui' directory.
    pause
    exit /b 1
)
echo ✅ Found Posterizarr.ps1
echo.

REM Check for Python
py -3 --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Python 3 is not installed or 'py.exe' is not in your PATH.
    pause
    exit /b 1
)

REM Check for Node.js
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js is not installed.
    pause
    exit /b 1
)

REM Backend Setup
echo 📦 Setting up Python backend...
cd backend
if not exist "venv\" (
    py -3 -m venv venv
)
call venv\Scripts\activate.bat && pip install -r requirements.txt
cd ..

REM Frontend Setup
echo 📦 Installing Frontend Dependencies...
cd frontend
call npm install
cd ..

echo ✅ Setup Complete!

REM Start Backend with .env Parsing

:: 1. Set default values
set "FINAL_HOST=127.0.0.1"
set "FINAL_PORT=8000"

:: 2. Check if .env exists and extract values
if exist "backend\.env" (
    echo 📝 Found .env file, parsing configuration...

    for /f "tokens=1,2 delims==" %%A in (backend\.env) do (
        if "%%A"=="APP_HOST" set "FINAL_HOST=%%B"
        if "%%A"=="PORT" set "FINAL_PORT=%%B"
    )
) else (
    echo 💡 No .env found, using default settings.
)

:: 3. Launch using the variables
echo 🔌 Starting Backend Server on %FINAL_HOST%:%FINAL_PORT%...
start cmd /k "cd backend && venv\Scripts\activate.bat && py -m uvicorn main:app --host %FINAL_HOST% --port %FINAL_PORT%"

echo.
echo 🎯 Next Steps:
echo.
echo 1. The Backend is now running in a separate window.
echo 2. In THIS terminal, start the frontend development server:
echo    cd frontend
echo    npm run dev
echo.
echo 3. Open your browser to the address shown in the frontend terminal.
echo.
pause