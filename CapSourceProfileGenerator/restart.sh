#!/bin/bash

echo "🔄 CapSource Profile Generator - Restart Script"
echo "=============================================="
echo ""

# Kill any process from PID file
PID_FILE="tmp/pids/server.pid"
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if [ -n "$PID" ]; then
    echo "🔍 Found PID file with process: $PID"
    if ps -p $PID > /dev/null 2>&1; then
      echo "🛑 Killing Rails server process $PID..."
      kill -9 $PID 2>/dev/null
      echo "✅ Process killed"
    else
      echo "⚠️  Process $PID not running (stale PID file)"
    fi
  fi
  echo "🗑️  Removing PID file..."
  rm -f "$PID_FILE"
fi

# Kill any process running on port 3000
echo "🔍 Checking for processes on port 3000..."
PORT_PID=$(lsof -ti:3000 2>/dev/null)

if [ -n "$PORT_PID" ]; then
  echo "⚠️  Found process(es) running on port 3000: $PORT_PID"
  echo "🛑 Killing process(es)..."
  kill -9 $PORT_PID 2>/dev/null
  echo "✅ Port 3000 cleared"
else
  echo "✅ No process found on port 3000"
fi

# Clean up any other stale PID files
echo "🧹 Cleaning up temporary files..."
rm -f tmp/pids/*.pid 2>/dev/null

echo ""
echo "📦 Installing/updating dependencies..."
bundle install

echo ""
echo "🗄️  Setting up database..."
bin/rails db:prepare

echo ""
echo "🚀 Starting Rails server on http://localhost:3000"
echo ""
echo "Press Ctrl+C to stop the server"
echo "=============================================="
echo ""

# Start the Rails server
bin/rails server
