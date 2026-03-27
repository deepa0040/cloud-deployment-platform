# Issues Encountered & Resolutions

This document details all issues encountered during the CodeDeploy infrastructure setup and their complete resolutions.

---

## Issue #1: CodeDeploy Agent Not Installed

### Problem
- **Error Message**: `Unit codedeploy-agent.service could not be found.`
- **Deployment Status**: ApplicationStop failed with `UnknownError`
- **Root Cause**: EC2 user data script used `yum` (Amazon Linux syntax) but instance was Ubuntu - package managers differ

### Details
- EC2 instance was launched with Ubuntu AMI but user data tried to install using `yum install`
- Ubuntu uses `apt-get` instead of `yum`
- CodeDeploy agent was never installed, so deployment couldn't proceed

### Solution
**Updated user data script in `child-module/ec2/main.tf`:**

```bash
#!/bin/bash
set -e

# Detect OS and install CodeDeploy agent accordingly
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$NAME
fi

# Install for Amazon Linux/RHEL
if [[ "$OS" == *"Amazon Linux"* ]] || [[ "$OS" == *"CentOS"* ]]; then
  yum update -y
  yum install -y ruby wget
  HOME_DIR="/home/ec2-user"
# Install for Ubuntu/Debian
elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
  apt-get update
  apt-get install -y ruby-full wget
  HOME_DIR="/home/ubuntu"
fi

# Download and install CodeDeploy agent
cd $HOME_DIR
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
chmod +x ./install
./install auto
systemctl start codedeploy-agent
systemctl enable codedeploy-agent
```

**Key Changes:**
- Detects OS type from `/etc/os-release`
- Uses `apt-get` for Ubuntu, `yum` for Amazon Linux
- Sets correct home directory based on detected OS
- Works for both Ubuntu and Amazon Linux

---

## Issue #2: Missing IAM Instance Profile

### Problem
- **Error Message**: `Missing credentials - please check if this instance was started with an IAM instance profile`
- **Deployment Stage**: ApplicationStop hook
- **Root Cause**: EC2 instance had no IAM role attached, so CodeDeploy agent couldn't authenticate

### Details
- CodeDeploy agent runs on EC2 and needs to call AWS APIs (fetch code from S3, poll for commands)
- Without IAM instance profile, agent has no credentials to sign AWS requests
- All lifecycle events failed because agent couldn't communicate with CodeDeploy service

### Solution
**Created new file `child-module/ec2/iam.tf`:**

```hcl
# IAM role for EC2 instance
resource "aws_iam_role" "ec2_codedeploy_role" {
  name = "EC2-CodeDeploy-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach AWS managed policies
resource "aws_iam_role_policy_attachment" "ec2_codedeploy_policy" {
  role       = aws_iam_role.ec2_codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_s3_policy" {
  role       = aws_iam_role.ec2_codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Create instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2-CodeDeploy-Profile"
  role = aws_iam_role.ec2_codedeploy_role.name
}
```

**Updated `main.tf` to use instance profile:**

```hcl
resource "aws_instance" "this" {
  ami                    = var.ami
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name  # NEW
  ...
}
```

**Policies Attached:**
- `AmazonSSMManagedInstanceCore` - For basic EC2 operations
- `AmazonS3ReadOnlyAccess` - For CodeDeploy to read deployment artifacts from S3

---

## Issue #3: Invalid User for BeforeInstall Hook

### Problem
- **Error Message**: `su: user ec2-user does not exist or the user entry does not contain all the required fields`
- **Deployment Stage**: BeforeInstall
- **Root Cause**: `appspec.yml` specified `runas: ec2-user` but Ubuntu instances don't have that user

### Details
- Generated appspec.yml had hardcoded `ec2-user` (Amazon Linux default)
- Ubuntu instances use `ubuntu` user instead
- CodeDeploy tried to execute hook scripts as non-existent user

### Solution
**Updated `sample-app/appspec.yml`:**

```yaml
hooks:
  ApplicationStop:
    - location: scripts/stop_server.sh
      timeout: 300
      runas: ubuntu          # Changed from ec2-user
  BeforeInstall:
    - location: scripts/install_dependencies.sh
      timeout: 300
      runas: ubuntu          # Changed from ec2-user
  ApplicationStart:
    - location: scripts/start_server.sh
      timeout: 300
      runas: ubuntu          # Changed from ec2-user
  ValidateService:
    - location: scripts/validate_service.sh
      timeout: 300
      runas: ubuntu          # Changed from ec2-user
```

**Added file ownership for Ubuntu:**

```yaml
permissions:
  - object: /var/www/sample-app
    pattern: "**"
    owner: ubuntu           # Changed from ec2-user
    group: ubuntu           # Changed from ec2-user
    mode: 755
```

---

## Issue #4: Directory Permission Denied

### Problem
- **Error Message**: `mkdir: cannot create directory '/var/www': Permission denied`
- **Deployment Stage**: BeforeInstall
- **Root Cause**: Script tried to create `/var/www` without `sudo`, but `ubuntu` user lacks permissions

### Details
- `/var/www` is a system directory owned by root
- `ubuntu` user (running the hook) cannot create directories there without sudo
- Script initially just called `mkdir -p /var/www/sample-app` without elevation

### Solution
**Updated `scripts/install_dependencies.sh`:**

```bash
# Install dependencies
if [ ! -d /var/www/sample-app ]; then
  sudo mkdir -p /var/www/sample-app              # Use sudo for creating system dir
  sudo chown -R ubuntu:ubuntu /var/www/sample-app 2>/dev/null || true  # Set ownership
fi
cd /var/www/sample-app
```

**Key Points:**
- Check if directory exists first (idempotent)
- Use `sudo` to create `/var/www` (system directory)
- Transfer ownership to `ubuntu` user so subsequent commands work
- Use `|| true` to prevent failure if ownership transfer doesn't work

---

## Issue #5: npm Command Not Found

### Problem
- **Error Message**: `sudo: npm: command not found`
- **Deployment Stage**: BeforeInstall
- **Root Cause**: Tried to run `npm install` as different user with `sudo -u ubuntu`, but npm was installed under root's NVM

### Details
- NVM (Node Version Manager) was installed by root during user data
- `sudo -u ubuntu npm` tried to run npm in ubuntu's environment where it wasn't installed
- NVM is user-specific and needs to be sourced in the user's shell context

### Solution
**Updated `scripts/install_dependencies.sh`:**

```bash
# Load NVM in the script context with the chosen user
export NVM_DIR="$HOME_DIR/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Run npm in ubuntu's bash login shell with NVM sourced
sudo -u "$DEPLOY_USER" bash -lc "source $NVM_DIR/nvm.sh && nvm use default && npm install --production"
```

**Key Changes:**
- Source NVM shell script in the same command
- Use `bash -lc` to invoke login shell (loads .bashrc/.bash_profile)
- Set NVM_DIR explicitly before sourcing
- This ensures npm command is found in ubuntu's environment

---

## Issue #6: nvm alias/use Warning in Noninteractive Mode

### Problem
- **Error Message**: `Please see 'nvm --help' or https://github.com/nvm-sh/nvm#nvmrc for more information.`
- **Deployment Stage**: BeforeInstall (continued but confusing)
- **Root Cause**: `nvm use --lts` was ambiguous in noninteractive scripts when no alias was set

### Details
- In interactive shells, nvm defaults well
- In noninteractive (CodeDeploy) shells, `nvm use --lts` without an alias can print warnings
- Didn't fail deployment but caused confusing logs

### Solution
**Updated `scripts/install_dependencies.sh` to set NVM alias:**

```bash
if ! command -v node &> /dev/null; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME_DIR/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm alias default 'lts/*'              # Set explicit default alias
    nvm use default                        # Use the alias instead of --lts
fi
```

**And in subsequent calls:**

```bash
sudo -u "$DEPLOY_USER" bash -lc "source $NVM_DIR/nvm.sh && nvm use default && npm install --production"
```

**Benefits:**
- Eliminates nvm warnings about detecting LTS
- Makes deployment logs cleaner
- Ensures consistent node version across runs

---

## Issue #7: Binary Execution in Different User Context

### Problem
- **Error**: `sudo -u ubuntu npm start` fails when npm isn't in ubuntu's PATH in some contexts
- **Root Cause**: Nested sudoing without proper shell login and NVM sourcing

### Solution
**Updated `scripts/start_server.sh`:**

```bash
#!/bin/bash
cd /var/www/sample-app
export NVM_DIR="/home/ubuntu/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Already running as ubuntu user (runas: ubuntu in appspec.yml), no need for nested sudo
source $NVM_DIR/nvm.sh
nvm use default
npm start > /tmp/sample-app.log 2>&1 &
```

**Key Insight:**
- Since `appspec.yml` already specifies `runas: ubuntu`, the hook runs as ubuntu user
- No need for nested `sudo -u ubuntu` - that was causing the conflict
- Simply source NVM and run npm directly as the already-correct user

---

## Summary of Root Causes

| Issue | Root Cause | Category |
|-------|-----------|----------|
| #1: No CodeDeploy Agent | OS detection failure (yum vs apt) | Infrastructure |
| #2: Missing IAM Profile | No instance profile attached | Security/IAM |
| #3: Invalid User | Hardcoded ec2-user for Ubuntu | Configuration |
| #4: Permission Denied | Non-root user creating /var/www | Permissions |
| #5: npm Not Found | NVM not sourced in user context | Environment |
| #6: nvm Warning | Ambiguous nvm use without alias | Configuration |
| #7: Nested sudo | Double sudoing with different users | Context |

## Prevention Strategies

1. **Always use OS detection** for mixed-OS environments
2. **Attach IAM profiles automatically** via Terraform
3. **Test scripts locally** before deploying
4. **Use proper shell contexts** (login shells for complex operations)
5. **Document environment dependencies** (NVM, Node, npm versions)
6. **Avoid nested sudo** - use appspec.yml `runas` parameter
7. **Make all scripts idempotent** (can run multiple times safely)

## Lessons Learned

✅ **Infrastructure as Code** catches many configuration issues early

✅ **OS detection** is essential for multi-platform deployments

✅ **IAM roles** must be set up correctly from infrastructure layer

✅ **User context matters** - always consider who runs the script

✅ **NVM is user-specific** - must source in user's shell context

✅ **appspec.yml runas parameter** handles user switching cleanly

✅ **Comprehensive logging** helps debug deployment issues quickly

---

## Testing the Final Solution

After all fixes, verify:

```bash
# All deployments complete with "Succeeded" status
aws deploy get-deployment --deployment-id d-XXXXX --query 'deploymentInfo.status'

# Application responds correctly
curl http://98.81.108.69:3000/
curl http://98.81.108.69:3000/health

# All lifecycle events passed
aws deploy get-deployment-instance --deployment-id d-XXXXX --instance-id i-XXXXX \
  --query 'instanceSummary.lifecycleEvents'
```

**Expected Output:**
```json
[
  { "lifecycleEventName": "ApplicationStop", "status": "Succeeded" },
  { "lifecycleEventName": "DownloadBundle", "status": "Succeeded" },
  { "lifecycleEventName": "BeforeInstall", "status": "Succeeded" },
  { "lifecycleEventName": "Install", "status": "Succeeded" },
  { "lifecycleEventName": "ApplicationStart", "status": "Succeeded" },
  { "lifecycleEventName": "ValidateService", "status": "Succeeded" }
]
```

---

## Additional Resources

- [CodeDeploy Troubleshooting Guide](https://docs.aws.amazon.com/codedeploy/latest/userguide/troubleshooting.html)
- [AppSpec File Reference](https://docs.aws.amazon.com/codedeploy/latest/userguide/app-spec-ref.html)
- [NVM Installation & Usage](https://github.com/nvm-sh/nvm)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
