#!/bin/bash
# Stop the Node.js application systemd service

# Stop the service
sudo systemctl stop sample-app.service 2>/dev/null || true

# Wait for graceful shutdown
sleep 2

# Verify service is stopped
if sudo systemctl is-active --quiet sample-app.service; then
  echo "⚠ Service still running, forcing kill..."
  pkill -9 -f "node server.js" || true
  pkill -9 -f "npm start" || true
else
  echo "✓ Service stopped successfully"
fi
