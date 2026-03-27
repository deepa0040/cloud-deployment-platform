# Systemd Service Configuration & Management Guide

## Overview

The Node.js application runs as a **systemd service** named `sample-app.service` on the EC2 instance. This provides production-grade process management with automatic restarts, logging, resource limits, and boot persistence.

## Service File Location

```
Primary:   /etc/systemd/system/sample-app.service
Source:    /var/www/sample-app/sample-app.service
```

## Service Configuration Details

### File: sample-app.service

```ini
[Unit]
Description=Node.js Sample Application
Documentation=file:///var/www/sample-app/README.md
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/sample-app

# Use NVM to load Node.js
ExecStart=/bin/bash -c 'source /home/ubuntu/.nvm/nvm.sh && nvm use default && npm start'

# Restart policy
Restart=always
RestartSec=5s

# Logging
StandardOutput=append:/var/log/sample-app/app.log
StandardError=append:/var/log/sample-app/error.log

# Resource limits (optional)
MemoryLimit=512M
CPUQuota=50%

# Environment variables
Environment="NODE_ENV=production"
Environment="NODE_PORT=3000"

[Install]
WantedBy=multi-user.target
```

### Configuration Explanation

| Setting | Value | Purpose |
|---------|-------|---------|
| **Type** | simple | Standard long-running service (default type) |
| **User** | ubuntu | Runs service as non-root user for security |
| **WorkingDirectory** | /var/www/sample-app | Sets working directory for Node.js app |
| **ExecStart** | npm start via NVM | Command to start the application |
| **Restart** | always | Restart if process exits for any reason |
| **RestartSec** | 5s | Wait 5 seconds before restarting |
| **MemoryLimit** | 512M | Maximum memory the process can use |
| **CPUQuota** | 50% | Limit CPU usage to 50% of one core |
| **StandardOutput** | append:/var/log/sample-app/app.log | Redirect stdout to file |
| **StandardError** | append:/var/log/sample-app/error.log | Redirect stderr to file |
| **NODE_ENV** | production | Set Node.js to production mode |
| **NODE_PORT** | 3000 | Application listening port |

## Service Lifecycle During CodeDeploy

### 1. **ApplicationStop** (scripts/stop_server.sh)
```bash
# Stop the running systemd service
sudo systemctl stop sample-app.service

# Wait for graceful shutdown
sleep 2

# Force kill if still running
pkill -9 -f "node server.js" || true
```
**Purpose:** Gracefully stop the current application before updating

---

### 2. **BeforeInstall** (scripts/install_dependencies.sh)
```bash
# Detect OS and install Node.js via NVM
# Create required directories
sudo mkdir -p /var/www/sample-app
sudo mkdir -p /var/log/sample-app

# Install npm dependencies
npm install --production

# Copy systemd service file
sudo cp /var/www/sample-app/sample-app.service /etc/systemd/system/

# Reload systemd daemon
sudo systemctl daemon-reload
```
**Purpose:** Prepare environment and register service with systemd

---

### 3. **ApplicationStart** (scripts/start_server.sh)
```bash
# Enable service to auto-start on boot
sudo systemctl enable sample-app.service

# Start the service
sudo systemctl start sample-app.service

# Verify it started
sudo systemctl status sample-app.service
```
**Purpose:** Start the application service and ensure it auto-starts on reboot

---

### 4. **ValidateService** (scripts/validate_service.sh)
```bash
# Check if service is running
sudo systemctl is-active sample-app.service

# Test health endpoint
curl -f http://localhost:3000/health

# Verify endpoint responds
echo "✓ Health check passed"
```
**Purpose:** Verify deployment was successful and app is healthy

---

## Systemd Service Management Commands

### Basic Status Commands

```bash
# Check current service status
sudo systemctl status sample-app.service

# Check if service is running (returns exit code 0 if running)
sudo systemctl is-active sample-app.service

# Check if service is enabled on boot
sudo systemctl is-enabled sample-app.service

# Show service details and configuration
sudo systemctl cat sample-app.service

# Show unit file location
sudo systemctl show sample-app.service -p FragmentPath
```

### Start/Stop/Restart Commands

```bash
# Start the service
sudo systemctl start sample-app.service

# Stop the service (graceful shutdown)
sudo systemctl stop sample-app.service

# Restart the service
sudo systemctl restart sample-app.service

# Reload configuration without restarting
sudo systemctl reload sample-app.service

# Try to restart, or start if not running
sudo systemctl try-restart sample-app.service
```

### Enable/Disable Boot Persistence

```bash
# Enable service to auto-start on instance reboot
sudo systemctl enable sample-app.service

# Disable auto-start on reboot
sudo systemctl disable sample-app.service

# Check if service is enabled
sudo systemctl is-enabled sample-app.service

# Enable and start in one command
sudo systemctl enable --now sample-app.service

# Disable and stop in one command
sudo systemctl disable --now sample-app.service
```

### Logging & Monitoring Commands

```bash
# View last 50 lines of service logs
sudo journalctl -u sample-app.service -n 50 --no-pager

# Follow service logs in real-time
sudo journalctl -u sample-app.service -f

# View logs since last boot
sudo journalctl -u sample-app.service -b

# View logs for specific time period
sudo journalctl -u sample-app.service --since "2 hours ago"

# View logs with timestamps
sudo journalctl -u sample-app.service -o short-iso

# View only error messages
sudo journalctl -u sample-app.service -p err

# View application stdout logs
sudo tail -f /var/log/sample-app/app.log

# View application stderr logs
sudo tail -f /var/log/sample-app/error.log

# View combined app logs
sudo tail -f /var/log/sample-app/*.log

# Count log lines to check size
wc -l /var/log/sample-app/*.log

# Check directory size
du -sh /var/log/sample-app/
```

### Troubleshooting Commands

```bash
# Show detailed service status
sudo systemctl status sample-app.service -l --no-pager

# Show service runtime information
sudo systemctl show sample-app.service

# Check if service would start (dry-run)
sudo systemctl --dry-run restart sample-app.service

# Validate service file syntax
sudo systemd-analyze verify /etc/systemd/system/sample-app.service

# Show service dependencies
sudo systemctl list-dependencies sample-app.service

# Check systemd logs for service issues
sudo journalctl -xe

# Force reload systemd manager configuration
sudo systemctl daemon-reload

# Reset failed service state
sudo systemctl reset-failed sample-app.service
```

### Service Process Commands

```bash
# Find the service process ID
ps aux | grep "node server.js"
ps aux | grep "sample-app"

# Show process resource usage
ps -eo pid,cmd,%cpu,%mem | grep node

# Monitor process in real-time
top -p $(pgrep -f "node server.js")

# Kill process (if service won't stop)
sudo kill -9 <PID>

# List all processes for ubuntu user
ps -u ubuntu
```

## Monitoring & Health Checks

### Application Health Endpoint

```bash
# Test application health
curl http://localhost:3000/health
# Expected output: OK (HTTP 200)

# Test main endpoint with verbose output
curl -v http://localhost:3000/

# Check response time
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:3000/health
```

### Service Online Check Script

```bash
#!/bin/bash
# Check if service and application are healthy

echo "Checking service status..."
if ! sudo systemctl is-active --quiet sample-app.service; then
  echo "✗ Service is NOT running"
  exit 1
fi
echo "✓ Service is running"

echo "Checking health endpoint..."
if ! curl -f http://localhost:3000/health > /dev/null 2>&1; then
  echo "✗ Application health check FAILED"
  exit 1
fi
echo "✓ Application is healthy"

echo "Checking memory usage..."
MEMORY=$(ps -eo cmd,%mem | grep "node server.js" | awk '{print $NF}')
echo "  Memory usage: ${MEMORY}%"

echo "✓ All checks passed"
```

## Common Tasks

### Tail Application Logs

```bash
# Real-time stdout logs
sudo tail -f /var/log/sample-app/app.log

# Real-time stderr logs
sudo tail -f /var/log/sample-app/error.log

# Last 100 lines of stdout
sudo tail -100 /var/log/sample-app/app.log

# Search logs for errors
sudo grep -i "error" /var/log/sample-app/app.log

# Show logs with line numbers
sudo tail -f -n +1 /var/log/sample-app/app.log | cat -n
```

### Restart Application During Deployment

```bash
# Clean stop and start
sudo systemctl stop sample-app.service
sudo systemctl start sample-app.service

# Or in one command
sudo systemctl restart sample-app.service

# Wait for service to be ready
sleep 2

# Verify service is running
sudo systemctl is-active sample-app.service
```

### Check Resource Limits

```bash
# View memory limit
sudo systemctl show sample-app.service -p MemoryLimit

# View CPU quota
sudo systemctl show sample-app.service -p CPUQuota

# View all resource limits
sudo systemctl show sample-app.service | grep -i "limit\|quota\|memory"

# Check actual usage
ps aux | grep "node server.js" | grep -v grep
```

### Enable Debug Logging

```bash
# Set systemd log level to debug
sudo journalctl -u sample-app.service -p debug

# Get verbose service status
systemctl status sample-app.service --verbose

# Show all environment variables
sudo systemctl show-environment

# Show service environment
sudo systemctl show sample-app.service --all
```

## Systemd Service States

| State | Description |
|-------|-------------|
| **active (running)** | Service is currently running |
| **active (exited)** | Service completed successfully (one-time service) |
| **inactive (dead)** | Service is stopped |
| **failed** | Service failed to start or crashed |
| **reloading** | Service is reloading configuration |
| **deactivating** | Service is in the process of stopping |

Check state with:
```bash
sudo systemctl status sample-app.service
```

## Service Dependencies

```
graph
CodeDeploy Agent
    ↓
ApplicationStop (stop systemd service)
    ↓
BeforeInstall (install deps, setup service)
    ↓
ApplicationStart (enable & start service)
    ↓
ValidateService (health check)
```

## Performance Tuning

### Increase Memory Limit

Edit `/etc/systemd/system/sample-app.service`:
```ini
[Service]
MemoryLimit=1G  # Change from 512M to 1GB
```

Then reload:
```bash
sudo systemctl daemon-reload
sudo systemctl restart sample-app.service
```

### Increase CPU Quota

```ini
[Service]
CPUQuota=100%  # Allow full CPU usage (or 200% for dual-core, etc.)
```

### Adjust Restart Delay

```ini
[Service]
RestartSec=10s  # Increase delay between restart attempts
```

## Backup & Recovery

### Backup Service Configuration

```bash
# Backup systemd service file
sudo cp /etc/systemd/system/sample-app.service /home/ubuntu/sample-app.service.backup

# Backup logs
sudo tar -czf sample-app-logs-backup.tar.gz /var/log/sample-app/

# Restore service file
sudo cp /home/ubuntu/sample-app.service.backup /etc/systemd/system/sample-app.service
sudo systemctl daemon-reload
```

### View Service Edit History

```bash
# If edited manually
ls -la /etc/systemd/system/sample-app.service

# Check modification time
stat /etc/systemd/system/sample-app.service
```

## Security Considerations

✅ **Runs as non-root user** (ubuntu) - Limited privileges  
✅ **Resource limits enforced** - Memory/CPU quotas  
✅ **Logs stored with restricted access** - Only ubuntu user can write  
✅ **No hardcoded credentials** - Uses NVM environment  
✅ **Auto-restart on crash** - Immediate recovery from failures  

## Integration with CodeDeploy

### Deployment Flow

1. **Download** - S3 artifact retrieved by CodeDeploy agent
2. **ApplicationStop** - Service stopped gracefully
3. **BeforeInstall** - Dependencies installed, service registered
4. **Install** - New code files copied
5. **ApplicationStart** - Service enabled and started
6. **ValidateService** - Health check confirms success

### Rollback on Validation Failure

If `ValidateService` fails:
- Deployment marked as **FAILED**
- Service remains in stopped state
- Previous version NOT automatically restored
- Manual intervention required for rollback

```bash
# Manual rollback steps
sudo systemctl stop sample-app.service
# Restore previous version files
git checkout previous-version
npm install --production
sudo systemctl start sample-app.service
```

## Monitoring Best Practices

### Regular Health Checks

```bash
# Add to crontab for monitoring (every 5 minutes)
*/5 * * * * systemctl is-active sample-app.service || sudo systemctl restart sample-app.service

# Check and log health
*/10 * * * * curl -f http://localhost:3000/health || echo "Health check failed at $(date)" >> /var/log/sample-app/health-check-log
```

### Log Rotation

Systemd journalctl automatically rotates logs. For file-based logs:

```bash
# Check current log size
du -sh /var/log/sample-app/*.log

# Create logrotate config
sudo tee /etc/logrotate.d/sample-app > /dev/null << EOF
/var/log/sample-app/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 ubuntu ubuntu
    sharedscripts
    postrotate
        sudo systemctl reload sample-app.service > /dev/null 2>&1 || true
    endscript
}
EOF
```

## Quick Reference

```bash
# Start service
sudo systemctl start sample-app.service

# Stop service
sudo systemctl stop sample-app.service

# Restart service
sudo systemctl restart sample-app.service

# Check status
sudo systemctl status sample-app.service

# View logs
sudo journalctl -u sample-app.service -f

# Enable on boot
sudo systemctl enable sample-app.service

# Disable on boot
sudo systemctl disable sample-app.service

# Health check
curl http://localhost:3000/health

# Show service config
sudo systemctl cat sample-app.service
```

## Useful Systemd Documentation

- Systemd service unit files: `man systemd.service`
- Systemd socket units: `man systemd.socket`
- Systemd mount units: `man systemd.mount`
- Systemd resource management: `man systemd.resource-control`
- Journalctl logging: `man journalctl`

## Emergency Procedures

### Service Stuck/Won't Stop

```bash
# Force kill all processes
sudo killall -9 node

# Reset service state
sudo systemctl reset-failed sample-app.service

# Restart service
sudo systemctl start sample-app.service
```

### Systemd Daemon Issues

```bash
# Reload systemd configuration
sudo systemctl daemon-reload

# Reexecute systemd manager
sudo systemctl daemon-reexec

# Check systemd status
systemctl status

# View all failed units
systemctl list-units --state=failed
```

### Clear Failed State

```bash
# Clear failed units
sudo systemctl reset-failed

# Remove service lock files (dangerous!)
sudo rm -f /var/run/systemd/notify
```

## Notes

- Service automatically restarts on crash (within 5 seconds)
- Memory limit set to 512MB to prevent memory leaks
- CPU quota at 50% prevents runaway processes
- All processes run as `ubuntu` user for security
- Logs stored in `/var/log/sample-app/` directory
- Service waits for network before starting (`After=network.target`)
