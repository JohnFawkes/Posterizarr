#!/bin/bash

echo "🚀 Posterizarr Web UI - Quick Setup"
echo "===================================="
echo ""

# Check directory
if [ ! -f "../Posterizarr.ps1" ]; then
    echo "❌ Error: Posterizarr.ps1 not found in parent directory"
    exit 1
fi

# Check Requirements
command -v python3 &> /dev/null || { echo "❌ Python 3 missing"; exit 1; }
command -v node &> /dev/null || { echo "❌ Node.js missing"; exit 1; }

echo "📦 Setting up Backend..."
cd backend
[ -d "venv" ] || python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cd ..

echo "📦 Installing Frontend Dependencies..."
cd frontend
npm install
cd ..

echo "✅ Setup Complete!"

echo ""
echo "🎯 NEXT STEPS:"
echo "--------------------------------------------------------"
echo "1. The Backend will start now in this terminal."
echo "2. Open a SECOND terminal tab/window for the Frontend:"
echo "   cd $(pwd)/frontend"
echo "   npm run dev"
echo "3. Access the UI at the address provided by the frontend."
echo "--------------------------------------------------------"
echo ""
read -n 1 -s -r -p "Press any key to start the Backend server..."
echo ""

# Start Backend with .env Parsing (Bash)

# 1. Set defaults
FINAL_HOST="127.0.0.1"
FINAL_PORT="8000"

# 2. Extract values if file exists
if [ -f "backend/.env" ]; then
    echo "📝 Parsing .env configuration..."
    # Extract value after '=', remove carriage returns (\r) for Windows compatibility
    FILE_HOST=$(grep "^APP_HOST=" backend/.env | cut -d'=' -f2 | tr -d '\r')
    FILE_PORT=$(grep "^PORT=" backend/.env | cut -d'=' -f2 | tr -d '\r')

    [ -n "$FILE_HOST" ] && FINAL_HOST=$FILE_HOST
    [ -n "$FILE_PORT" ] && FINAL_PORT=$FILE_PORT
fi

echo "🔌 Starting Backend Server on $FINAL_HOST:$FINAL_PORT..."
cd backend
source venv/bin/activate
python3 -m uvicorn main:app --host $FINAL_HOST --port $FINAL_PORT