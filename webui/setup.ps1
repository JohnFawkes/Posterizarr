# 🚀 Posterizarr Web UI - Quick Setup
# This script sets up the Python virtual environment for the backend
# and installs dependencies for both the frontend and backend.

Clear-Host
Write-Host ""
Write-Host "🚀 Posterizarr Web UI - Quick Setup"
Write-Host "===================================="
Write-Host ""

# Administrator Check
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "⚠️  WARNING: You are NOT running as Administrator." -ForegroundColor Yellow
    Write-Host "   If you need to install missing dependencies (Python/Node), this script will fail."
    Write-Host "   It is highly recommended to close this and run PowerShell as Administrator."
    Write-Host ""
    Start-Sleep -Seconds 2
} else {
    Write-Host "✅ Running as Administrator"
}

# Prerequisite Checks

# Check if we're in the right directory
if (-not (Test-Path "..\Posterizarr.ps1")) {
    Write-Host "❌ Error: Posterizarr.ps1 not found in parent directory." -ForegroundColor Red
    Write-Host "Please run this script from within the 'webui' directory."
    Read-Host "Press Enter to exit..."
    exit 1
}
Write-Host "✅ Found Posterizarr.ps1"

# Python Check (Python vs Py Launcher vs Winget)
$UsePyLauncher = $false
$PythonFound = $false

if (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonFound = $true
    Write-Host "✅ Python 3 found (python.exe)"
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonFound = $true
    $UsePyLauncher = $true
    Write-Host "✅ Python 3 found (py.exe launcher)"
}
else {
    Write-Host "❌ Python 3 is not installed." -ForegroundColor Red
    $install = Read-Host "   > Would you like to install Python 3 via Winget now? (Y/N)"

    if ($install -eq 'Y' -or $install -eq 'y') {
        if (-not $isAdmin) {
            Write-Host "❌ Error: Administrator privileges are required to install Python." -ForegroundColor Red
            Read-Host "Press Enter to exit..."
            exit 1
        }
        Write-Host "📦 Installing Python 3 via Winget..."
        winget install -e --id Python.Python.3 --accept-package-agreements --accept-source-agreements
        Write-Host "🔄 Refreshing Environment Variables..."
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        if (Get-Command python -ErrorAction SilentlyContinue) {
            $PythonFound = $true
            Write-Host "✅ Python 3 installed and detected." -ForegroundColor Green
        } else {
            Write-Host "⚠️  Python installed, but session cannot see it. Please restart script." -ForegroundColor Yellow
            Read-Host "Press Enter to exit..."
            exit 1
        }
    } else {
        Write-Host "❌ Setup cannot proceed without Python."
        exit 1
    }
}

# Node.js Check
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Host "✅ Node.js found"
} else {
    Write-Host "❌ Node.js is not installed." -ForegroundColor Red
    $installNode = Read-Host "   > Would you like to install Node.js via Winget now? (Y/N)"

    if ($installNode -eq 'Y' -or $installNode -eq 'y') {
        if (-not $isAdmin) {
            Write-Host "❌ Error: Administrator privileges are required."
            exit 1
        }
        Write-Host "📦 Installing Node.js via Winget..."
        winget install -e --id OpenJS.NodeJS --accept-package-agreements --accept-source-agreements
        Write-Host "🔄 Refreshing Environment Variables..."
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        if (Get-Command node -ErrorAction SilentlyContinue) {
            Write-Host "✅ Node.js installed and detected." -ForegroundColor Green
        } else {
            Write-Host "⚠️  Node.js installed, but session cannot see it. Please restart script." -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "❌ Setup cannot proceed without Node.js."
        exit 1
    }
}
Write-Host ""

# Backend Setup
Write-Host "📦 Setting up Python backend..."
Push-Location -Path "backend"

if (-not (Test-Path "venv")) {
    Write-Host "   - Creating virtual environment..."
    try {
        if ($UsePyLauncher) { py -3 -m venv venv } else { python -m venv venv }
    }
    catch {
        Write-Host "❌ Failed to create virtual environment." -ForegroundColor Red
        Pop-Location; exit 1
    }
} else {
    Write-Host "   - Virtual environment already exists."
}

Write-Host "   - Installing Python dependencies..."
try {
    .\venv\Scripts\pip.exe install -r requirements.txt | Out-Null
    Write-Host "✅ Backend dependencies installed." -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to install backend dependencies." -ForegroundColor Red
    Pop-Location; exit 1
}
Pop-Location
Write-Host ""

# Frontend Setup
Write-Host "📦 Installing Frontend Dependencies..."
Push-Location -Path "frontend"
try {
    npm install
    Write-Host "✅ Frontend dependencies installed." -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install frontend dependencies." -ForegroundColor Red
}
Pop-Location
Write-Host ""

# Automation & Launch
Write-Host "🎉 Setup Complete!" -ForegroundColor Green
Write-Host ""

$autoRun = Read-Host "🚀 Do you want to build the frontend and start the app now? (Y/N)"

if ($autoRun -eq 'Y' -or $autoRun -eq 'y') {

    # Step A: Build Frontend
    Write-Host "🔨 Building Frontend (this may take a moment)..." -ForegroundColor Cyan
    Push-Location -Path "frontend"
    try {
        npm run build
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Frontend Build Success." -ForegroundColor Green
        } else {
            throw "NPM Build failed."
        }
    }
    catch {
        Write-Host "❌ Frontend build failed. Cannot start application." -ForegroundColor Red
        Pop-Location
        Read-Host "Press Enter to exit..."
        exit 1
    }
    Pop-Location

    # Step B: Start Backend in New Window
    Write-Host "🔌 Starting Backend Server in a new window..." -ForegroundColor Cyan
    $backendPath = Join-Path $PSScriptRoot "backend"

    # Determine python command for the new window
    $pyCmd = if ($UsePyLauncher) { "py" } else { "python" }

    # Start Backend with .env Parsing

    # 1. Set default values
    $finalHost = "127.0.0.1"
    $finalPort = "8000"
    $backendPath = Join-Path $PSScriptRoot "backend"
    $envPath = Join-Path $backendPath ".env"

    # 2. Check if .env exists and parse values
    if (Test-Path $envPath) {
        Write-Host "📝 Found .env file, parsing configuration..." -ForegroundColor Gray

        # Read the file and look for specific keys
        $envContent = Get-Content $envPath
        foreach ($line in $envContent) {
            if ($line -match "^APP_HOST=(.*)") {
                $finalHost = $matches[1].Trim()
            }
            if ($line -match "^PORT=(.*)") {
                $finalPort = $matches[1].Trim()
            }
        }
    } else {
        Write-Host "💡 No .env found, using default settings." -ForegroundColor Gray
    }

    # 3. Start Backend in New Window
    Write-Host "🔌 Starting Backend Server on $($finalHost):$($finalPort)..." -ForegroundColor Cyan

    # Determine python command
    $pyCmd = if ($UsePyLauncher) { "py" } else { "python" }

    # Construct the command block with the parsed variables
    $commands = "Set-Location '$backendPath'; .\venv\Scripts\Activate.ps1; $pyCmd -m uvicorn main:app --host $finalHost --port $finalPort"

    # Launch new PowerShell process
    Start-Process pwsh -ArgumentList "-NoExit", "-Command", "& {$commands}"
    # Step C: Open Browser
    Write-Host "🌐 Opening Browser..." -ForegroundColor Cyan
    Start-Sleep -Seconds 3 # Give uvicorn a moment to spin up
    Start-Process "http://localhost:8000"

} else {
    # Fallback to manual instructions if they said No
    Write-Host "🎯 Manual Next Steps:" -ForegroundColor Yellow
    Write-Host "1. cd webui\frontend -> npm run build"
    Write-Host "2. cd webui\backend -> .\venv\Scripts\Activate.ps1 -> python -m uvicorn main:app --host 127.0.0.1 --port 8000"
}

Read-Host "Press Enter to close this setup window..."