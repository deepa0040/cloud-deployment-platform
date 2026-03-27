#!/bin/bash
# Start the Node.js application as a systemd service

# Enable the service to start on boot
sudo systemctl enable sample-app.service

# Start the service
sudo systemctl start sample-app.service

# Verify service started successfully
sleep 2
sudo systemctl status sample-app.service

echo "✓ Node.js application service started successfully"
