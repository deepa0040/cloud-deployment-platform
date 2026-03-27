#!/bin/bash
set -e

# Detect user for Ubuntu vs Amazon Linux
if id ubuntu >/dev/null 2>&1; then
  DEPLOY_USER="ubuntu"
  HOME_DIR="/home/ubuntu"
elif id ec2-user >/dev/null 2>&1; then
  DEPLOY_USER="ec2-user"
  HOME_DIR="/home/ec2-user"
else
  echo "No supported deploy user found (ubuntu or ec2-user), exiting"
  exit 1
fi

# Install Node.js and nvm if not present
if ! command -v node &> /dev/null; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME_DIR/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm alias default 'lts/*'
    nvm use default
fi

# Install dependencies
sudo mkdir -p /var/www/sample-app
sudo chown -R "$DEPLOY_USER":"$DEPLOY_USER" /var/www/sample-app 2>/dev/null || true
cd /var/www/sample-app

# Load nvm in current session with the chosen user
export NVM_DIR="$HOME_DIR/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

sudo -u "$DEPLOY_USER" bash -lc "source $NVM_DIR/nvm.sh && nvm use default && node --version && npm --version && npm install --production"

# Set up systemd service for the application
echo "Setting up systemd service for Node.js application..."

# Create log directory
sudo mkdir -p /var/log/sample-app
sudo chown -R "$DEPLOY_USER":"$DEPLOY_USER" /var/log/sample-app
sudo chmod 755 /var/log/sample-app

# Copy systemd service file to /etc/systemd/system/
sudo cp /var/www/sample-app/sample-app.service /etc/systemd/system/sample-app.service
sudo chmod 644 /etc/systemd/system/sample-app.service

# Reload systemd daemon to recognize new service
sudo systemctl daemon-reload

echo "✓ Systemd service configuration complete"
