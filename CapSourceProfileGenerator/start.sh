#!/bin/bash

echo "🚀 CapSource Profile Generator - Quick Start"
echo "=============================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
  echo "⚠️  Warning: .env file not found!"
  echo "📝 Creating .env from .env.example..."
  cp .env.example .env
  echo "⚠️  Please edit .env and add your OPENAI_API_KEY before continuing"
  echo ""
  read -p "Press Enter after you've added your API key to .env..."
fi

# Check for existing Rails server
PID_FILE="tmp/pids/server.pid"
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if ps -p $PID > /dev/null 2>&1; then
    echo "⚠️  Rails server already running (PID: $PID)"
    echo "💡 Use ./restart.sh to restart the server"
    echo ""
    exit 1
  else
    echo "🗑️  Removing stale PID file..."
    rm -f "$PID_FILE"
  fi
fi

# Check if port 3000 is in use
if lsof -ti:3000 > /dev/null 2>&1; then
  echo "⚠️  Port 3000 is already in use"
  echo "💡 Use ./restart.sh to kill existing processes and restart"
  echo ""
  exit 1
fi

echo "📦 Installing dependencies..."
bundle install

echo ""
echo "🗄️  Setting up database..."
bin/rails db:prepare

echo ""
echo "🚀 Starting Rails server on http://localhost:3000"
echo ""
echo "✨ Visit http://localhost:3000 to use the app"
echo "Press Ctrl+C to stop the server"
echo "=============================================="
echo ""

# Start the Rails server
bin/rails server
