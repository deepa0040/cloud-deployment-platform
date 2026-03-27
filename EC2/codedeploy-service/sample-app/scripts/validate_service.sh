#!/bin/bash
# Validate that the systemd service is running and responding to health checks

echo "Checking systemd service status..."
sudo systemctl is-active --quiet sample-app.service
if [ $? -ne 0 ]; then
  echo "✗ Service is not running"
  exit 1
fi
echo "✓ Service is running"

echo "Checking health endpoint..."
sleep 2  # Wait for service to be ready
curl -f http://localhost:3000/health
if [ $? -ne 0 ]; then
  echo "✗ Health check failed"
  exit 1
fi
echo "✓ Application is healthy"
