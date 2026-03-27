# CodeDeploy Deployment Documentation

## Overview

This document explains AWS CodeDeploy and how code is deployed in this project. It covers the deployment architecture, lifecycle events, and the complete flow from code commit to running application.

---

## What is AWS CodeDeploy?

AWS CodeDeploy is a **fully managed deployment service** that automates application deployments to various compute services including EC2 instances, on-premises servers, and Lambda functions.

### Key Characteristics

- **Fully Managed**: AWS handles infrastructure and availability
- **Automated**: Reduces manual errors through scripting
- **Flexible**: Supports multiple deployment targets and strategies
- **Safe**: Built-in rollback and health monitoring capabilities
- **Trackable**: Complete audit trail of all deployments

### Benefits for Your Project

✅ Automatic code deployment without SSH access  
✅ Consistent deployments across instances  
✅ Automated health checks and validation  
✅ Easy rollback if deployment fails  
✅ Audit trail for compliance  
✅ Scheduled or triggered deployments  

---

## CodeDeploy Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS CodeDeploy Service                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1. CodeDeploy Application                                  │
│     └─ Logical container for deployment configuration       │
│                                                               │
│  2. Deployment Group                                        │
│     └─ Collection of EC2 instances to deploy to             │
│     └─ Deployment strategy and rules                        │
│                                                               │
│  3. Deployment                                              │
│     └─ Single deployment execution                          │
│     └─ References specific code revision                    │
│     └─ Tracks status and lifecycle events                   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
           │
           │ Communicates with
           ▼
┌─────────────────────────────────────────────────────────────┐
│                EC2 Instance (Ubuntu)                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  CodeDeploy Agent (Daemon)                                  │
│  ├─ Polls CodeDeploy service for commands                   │
│  ├─ Downloads application code from S3                      │
│  ├─ Executes lifecycle hooks (scripts)                      │
│  ├─ Reports deployment status                               │
│  └─ Handles rollbacks                                       │
│                                                               │
└─────────────────────────────────────────────────────────────┘
           │
           │ Gets artifacts from
           ▼
┌─────────────────────────────────────────────────────────────┐
│              S3 Bucket (Artifact Storage)                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  sample-app.tar.gz  ← Packaged application code             │
│                       & deployment scripts                   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Component Relationships

```
Application Configuration (CodeDeploy)
         │
         ├─→ EC2 Instance with CodeDeploy Agent
         │
         └─→ S3 Bucket with Application Code
                    │
                    └─→ AppSpec.yml (deployment instructions)
                         ├─→ scripts/ (lifecycle hooks)
                         └─→ application files
```

---

## Your Project's Deployment Setup

### Created Resources

#### 1. CodeDeploy Application
- **Name**: `my-app`
- **Type**: EC2/On-premises
- **Platform**: Linux
- **Function**: Logical container for all deployments

#### 2. Deployment Group
- **Name**: `my-deployment-group`
- **Target**: EC2 instances tagged with `Name=CodeDeploy-EC2`
- **Configuration**: In-place deployment (replace running instance)
- **Strategy**: One-at-a-time (proceed only when previous succeeds)

#### 3. EC2 Instance
- **AMI**: Ubuntu (automatically detects OS)
- **IAM Role**: `EC2-CodeDeploy-Role` with S3 and CodeDeploy permissions
- **CodeDeploy Agent**: Installed and running via user data
- **Tag**: `Name=CodeDeploy-EC2` (used for targeting)

#### 4. S3 Bucket
- **Name**: `my-codedeploy-bucket-<timestamp>`
- **Purpose**: Store `sample-app.tar.gz` (packaged application)
- **Permissions**: EC2 instance has read-only access via IAM role

---

## Deployment Lifecycle

### Step-by-Step Flow

```
User triggers deployment
         │
         ▼
Developer packages app code
    tar -czf sample-app.tar.gz
         │
         ▼
Upload to S3
    aws s3 cp sample-app.tar.gz s3://bucket/
         │
         ▼
Create CodeDeploy Deployment
    aws deploy create-deployment
         │
         ▼
CodeDeploy Service receives request
    - Creates deployment record
    - Assigns deployment ID
    - Queues for target instances
         │
         ▼
CodeDeploy Agent polls for commands (every ~30 seconds)
    - Agent sees new deployment
    - Downloads appspec.yml from S3
    - Executes lifecycle events in order
         │
         ▼
LIFECYCLE EVENTS (see below)
         │
         ▼
CodeDeploy Service updates status
    - Succeeded / Failed / Stopped
         │
         ▼
Deployment Complete
```

---

## Deployment Lifecycle Events

CodeDeploy executes the following hooks **in order** during each deployment:

### Event Timeline

```
┌─────────────────────────────────────────────────────────────┐
│  LIFECYCLE EVENT SEQUENCE                                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1. ApplicationStop (timeout: 300s)                          │
│     Script: scripts/stop_server.sh                           │
│     User: ubuntu                                             │
│     ├─ Kill existing npm processes                           │
│     ├─ Return exit code 0 (success) regardless              │
│     └─ Idempotent (safe to run if already stopped)          │
│                                                               │
│  2. DownloadBundle (automatic)                              │
│     ├─ CodeDeploy downloads app from S3                     │
│     ├─ Extracts to deployment directory                     │
│     └─ No user script needed                                │
│                                                               │
│  3. BeforeInstall (timeout: 300s)                           │
│     Script: scripts/install_dependencies.sh                 │
│     User: ubuntu                                             │
│     ├─ Detect ubuntu vs ec2-user                            │
│     ├─ Install NVM (Node Version Manager)                   │
│     ├─ Install Node.js (LTS version)                        │
│     ├─ Create /var/www/sample-app directory                │
│     └─ Set ownership to ubuntu user                         │
│                                                               │
│  4. Install (automatic)                                     │
│     ├─ CodeDeploy copies files to destination               │
│     ├─ Destination: /var/www/sample-app                     │
│     ├─ Preserves file permissions from appspec.yml          │
│     └─ No user script needed                                │
│                                                               │
│  5. AfterInstall (optional)                                 │
│     Script: (not used in our setup)                         │
│     Can be used for cleanup or setup tasks                  │
│                                                               │
│  6. ApplicationStart (timeout: 300s)                        │
│     Script: scripts/start_server.sh                         │
│     User: ubuntu                                             │
│     ├─ Load NVM environment                                 │
│     ├─ Set Node.js version                                  │
│     ├─ Start app: npm start (background)                    │
│     └─ Logs to /tmp/sample-app.log                          │
│                                                               │
│  7. ValidateService (timeout: 300s)                        │
│     Script: scripts/validate_service.sh                     │
│     User: ubuntu                                             │
│     ├─ Curl http://localhost:3000/health                    │
│     ├─ Expect HTTP 200 with "OK"                            │
│     ├─ Fail if health check returns error                   │
│     └─ If fails, triggerApplicationStop & rollback          │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Event Execution Details

#### 1. ApplicationStop
```bash
# Command run as ubuntu user
pkill -f "node server.js" || true
pkill -f "npm start" || true
```
- Gracefully stops running processes
- `|| true` ensures script succeeds even if no process found
- Critical for zero-data-loss updates

#### 2. BeforeInstall
```bash
# Detects Ubuntu vs Amazon Linux
# Installs NVM and Node.js
# Creates /var/www/sample-app
# Runs: npm install --production
```
- Installs all Node.js dependencies
- Uses `--production` flag to skip dev dependencies
- Takes 30-60 seconds typically

#### 3. Install
```bash
# CodeDeploy copies files from extracted archive to
# /var/www/sample-app/
```
- Handled automatically by CodeDeploy
- Respects file permissions from appspec.yml
- Overwrites existing files (safe because app stopped)

#### 4. ApplicationStart
```bash
# Start Node.js server in background
npm start > /tmp/sample-app.log 2>&1 &
```
- Starts Express.js server on port 3000
- Runs in background (ampersand &)
- Logs output for debugging

#### 5. ValidateService
```bash
# Health check validation
curl -f http://localhost:3000/health
```
- Polls `/health` endpoint
- Expects HTTP 200 response
- If fails, triggers rollback
- This is the **safety gate** of deployment

---

## Deployment Sequence in Your Project

### Before Deployment (Setup)

```
Terraform creates:
├─ EC2 Instance (Ubuntu)
├─ CodeDeploy Agent (via user data)
├─ IAM Role (S3 + CodeDeploy permissions)
└─ CodeDeploy Application & Deployment Group
```

### During Deployment

```
1. Developer runs:
   aws deploy create-deployment \
     --application-name my-app \
     --deployment-group-name my-deployment-group \
     --s3-location bucket=...,key=sample-app.tar.gz

2. CodeDeploy Service:
   - Creates deployment record (ID: d-XXXXX)
   - Sets status to "InProgress"
   - Queues to deployment group

3. CodeDeploy Agent on EC2:
   - Polls CodeDeploy API (~every 30s)
   - Receives deployment command
   - Downloads appspec.yml from S3
   - Begins lifecycle events

4. Lifecycle Hooks Execute (in order):
   ApplicationStop     → scripts/stop_server.sh
   DownloadBundle     → (automatic)
   BeforeInstall      → scripts/install_dependencies.sh
   Install            → (automatic)
   ApplicationStart   → scripts/start_server.sh
   ValidateService    → scripts/validate_service.sh

5. CodeDeploy Service Updates:
   - Tracks success/failure of each event
   - Final status: "Succeeded" or "Failed"

6. User verifies:
   curl http://<public-ip>:3000/
```

---

## Configuration File: appspec.yml

This file controls deployment behavior:

```yaml
version: 0.0                          # AppSpec version
os: linux                             # Operating system

files:                                # Source → Destination
  - source: /
    destination: /var/www/sample-app

permissions:                          # File ownership & permissions
  - object: /var/www/sample-app
    pattern: "**"
    owner: ubuntu
    group: ubuntu
    mode: 755

hooks:                                # Lifecycle event scripts
  ApplicationStop:
    - location: scripts/stop_server.sh
      timeout: 300
      runas: ubuntu
  BeforeInstall:
    - location: scripts/install_dependencies.sh
      timeout: 300
      runas: ubuntu
  ApplicationStart:
    - location: scripts/start_server.sh
      timeout: 300
      runas: ubuntu
  ValidateService:
    - location: scripts/validate_service.sh
      timeout: 300
      runas: ubuntu
```

### Key Fields Explained

- **version**: AppSpec format version (always 0.0 for EC2)
- **os**: Target OS (linux or windows)
- **files**: Maps source files in archive to EC2 paths
- **permissions**: Sets file ownership and mode after copy
- **hooks**: Scripts to run at specific lifecycle points
- **runas**: Which user runs the script (ubuntu in our case)
- **timeout**: Seconds allowed for script execution

---

## Error Handling & Rollback

### Automatic Rollback Triggers

```
Deployment fails automatically if:

1. ApplicationStop fails
   → Agent cannot stop app
   → Likely environment issue

2. BeforeInstall fails
   → Missing dependencies or permissions
   → See issues.md for solutions

3. ApplicationStart fails
   → App won't start (process exits immediately)
   → Check /tmp/sample-app.log

4. ValidateService fails
   → Health check returns non-200 status
   → App crashed or misconfigured
   → **Most common failure point**
```

### Rollback Mechanism

```
If ValidateService fails:

1. CodeDeploy stops the deployment
2. Runs ApplicationStop on current (failed) version
3. Restores previous working version (if available)
4. Runs ApplicationStart with previous code
5. Confirms with ValidateService
6. Status: "Failed" (but previous version running)
```

**Important**: CodeDeploy doesn't automatically keep previous versions. First deployment has no rollback target.

---

## Monitoring Deployments

### Check Deployment Status

```bash
# Real-time status
aws deploy get-deployment \
  --deployment-id d-XXXXX \
  --query 'deploymentInfo.status' \
  --output text

# Expected outputs:
# - Pending
# - InProgress
# - Succeeded
# - Failed
# - Stopped
```

### View Instance-Level Details

```bash
aws deploy get-deployment-instance \
  --deployment-id d-XXXXX \
  --instance-id i-XXXXX \
  --query 'instanceSummary.lifecycleEvents'
```

### Full Deployment Information

```bash
aws deploy get-deployment \
  --deployment-id d-XXXXX \
  --output json | jq .
```

### Watch Real-Time Logs

```bash
# On EC2 instance, view CodeDeploy agent logs
ssh -i key.pem ubuntu@<public-ip>
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log

# View application logs
sudo tail -f /tmp/sample-app.log
```

---

## Downtime Analysis

### Current Deployment (Single Instance)

```
Timeline during deployment:

T=0s    ApplicationStop    ← App DOWN starts
T=5s    DownloadBundle     
T=10s   BeforeInstall      ← npm install (30-60s)
T=40s   Install            
T=45s   ApplicationStart   ← App UP starts
        (wait for process ready)
T=50s   ValidateService    ← App UP confirmed
        
TOTAL DOWNTIME: ~45-50 seconds
```

### Zero-Downtime Deployment (Future)

To achieve zero downtime, implement Blue/Green:

```
Blue Instance (Running)
        │
        ├─→ Receive user requests
        │
Green Instance (Deploying)
        │
        ├─→ Download code
        ├─→ Install dependencies
        ├─→ Start app
        ├─→ Validate service
        │
        └─→ Health check passes
                │
                ▼
        Switch traffic Blue → Green
        
TOTAL DOWNTIME: 0 seconds (traffic seamless)
```

---

## Deployment Best Practices

### 1. Testing Locally
```bash
npm install
npm start
curl http://localhost:3000/health
# Verify before packaging
```

### 2. Semantic Versioning
```bash
# Version in package.json
"version": "2.0.0"
# Helps track deployments
```

### 3. Comprehensive Health Check
```javascript
// app.js health endpoint
app.get('/health', (req, res) => {
  // Check database connection
  // Check external service connectivity
  // Check required resources
  res.status(200).json({ status: 'healthy' });
});
```

### 4. Graceful Shutdown
```bash
# In stop_server.sh
# Give app time to close connections
sleep 2
pkill -f "npm start"
```

### 5. Deployment Notifications
```bash
# Send alert before deployment
# Log deployment to monitoring system
# Notify team when deployment succeeds/fails
```

### 6. Automated Testing
```bash
# In ValidateService, run comprehensive tests
curl -f http://localhost:3000/health || exit 1
curl -f http://localhost:3000/api/endpoints || exit 1
# Ensures robust validation
```

---

## Common Deployment Scenarios

### Scenario 1: Bug Fix Deployment
```
1. Fix bug in server.js
2. Test locally: npm start + curl tests
3. Increment version in package.json
4. Package: tar -czf sample-app.tar.gz .
5. Upload: aws s3 cp sample-app.tar.gz s3://bucket/
6. Deploy: aws deploy create-deployment ...
7. Verify: curl http://public-ip/
```

### Scenario 2: Dependency Update
```
1. Update express in package.json
2. Local: npm install && npm start
3. Test all endpoints
4. Package: tar -czf sample-app.tar.gz .
5. Upload & Deploy
6. Monitor for issues
```

### Scenario 3: Configuration Change
```
1. Add environment variable to start_server.sh
2. Test locally with: PORT=8080 npm start
3. Package & Deploy
4. Verify with: curl http://public-ip:3000/
```

### Scenario 4: Emergency Rollback
```
1. Check current deployment failed: d-XXXXX
2. Revert code to previous version
3. Package: tar -czf sample-app.tar.gz .
4. Deploy: aws deploy create-deployment ...
5. Verify: curl http://public-ip/health
```

---

## Deployment Statistics

### Average Timings

| Event | Typical Duration | Range |
|-------|-----------------|-------|
| ApplicationStop | 2-5s | 1-10s |
| DownloadBundle | 3-5s | 2-10s |
| BeforeInstall | 30-60s | 20-90s* |
| Install | 2-5s | 1-10s |
| ApplicationStart | 1-3s | <1-5s |
| ValidateService | 1-2s | <1-5s |
| **TOTAL** | **40-80s** | **25-120s** |

*First deployment takes longer due to NVM/Node installation

### Success Rates

- **Typical success rate**: 95-99%
- **Main failure point**: ValidateService (health check)
- **Most common cause**: App crashes or dependencies not installed

---

## Troubleshooting Guides

### Deployment Stuck in "InProgress"
- Check CodeDeploy agent: `sudo systemctl status codedeploy-agent`
- Check network to S3: `aws s3 ls`
- Check logs: `/var/log/aws/codedeploy-agent/codedeploy-agent.log`

### ValidateService Fails
- Check app health: `curl http://localhost:3000/health`
- View app logs: `cat /tmp/sample-app.log`
- Verify port 3000 accessible: `netstat -tlnp | grep 3000`

### npm install Timeout
- Check NVM installation: `ls /home/ubuntu/.nvm`
- Check disk space: `df -h`
- Check npm cache: `npm cache clean --force`

See **issues.md** for detailed resolution steps.

---

## Next Steps

1. ✅ Deploy initial version (done)
2. 📊 Set up monitoring dashboard
3. 🔄 Add automated deployments (GitHub Actions / Jenkins)
4. 📈 Implement Blue/Green deployment (zero downtime)
5. 🔐 Add deployment approvals and gates
6. 📝 Document runbooks for team
7. 🧪 Add integration tests to ValidateService
8. 📱 Set up deployment notifications

---

## Reference Commands

### View all deployments
```bash
aws deploy list-deployments --application-name my-app
```

### Get deployment detailed status
```bash
aws deploy describe-deployment --deployment-id d-XXXXX
```

### List deployment instances
```bash
aws deploy list-deployment-instances --deployment-id d-XXXXX
```

### Stop a deployment
```bash
aws deploy stop-deployment --deployment-id d-XXXXX --auto-rollback-enabled
```

### Create a deployment
```bash
aws deploy create-deployment \
  --application-name my-app \
  --deployment-group-name my-deployment-group \
  --s3-location bucket=my-bucket,key=app.tar.gz,bundleType=tar
```

---

## Useful Links

- [AWS CodeDeploy User Guide](https://docs.aws.amazon.com/codedeploy/)
- [AppSpec File Reference](https://docs.aws.amazon.com/codedeploy/latest/userguide/application-revision-structure.html)
- [CodeDeploy Agent Reference](https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent.html)
- [Troubleshooting CodeDeploy](https://docs.aws.amazon.com/codedeploy/latest/userguide/troubleshooting.html)
