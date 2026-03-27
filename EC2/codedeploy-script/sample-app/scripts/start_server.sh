#!/bin/bash
# Start the Node.js application
cd /var/www/sample-app
export NVM_DIR="/home/ubuntu/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Already running as ubuntu user (runas: ubuntu in appspec.yml), no need for sudo
source $NVM_DIR/nvm.sh
nvm use default
npm start > /tmp/sample-app.log 2>&1 &