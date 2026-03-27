#!/bin/bash
# Stop the Node.js application
pkill -f "node server.js" || true
pkill -f "npm start" || true
pkill -f "pm2" || true