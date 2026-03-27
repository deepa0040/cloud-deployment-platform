# CodeDeploy with Systemd Service

This directory contains a **production-ready** CodeDeploy infrastructure setup that runs the Node.js application as a **systemd service** for better process management and reliability.

## Key Differences from codedeploy-script

| Feature | codedeploy-script | codedeploy-service |
|---------|-------------------|-------------------|
| **Execution** | Background process (npm start &) | Systemd service (always running) |
| **Auto-Restart** | Manual process monitoring | Automatic restart on failure |
| **Boot Persistence** | Manual restart required | Auto-start on instance reboot |
| **Logging** | File-based only | Journalctl + file-based |vv
| **Resource Management** | Unlimited | Memory/CPU limits enforced |
| **Process Control** | Kill signals | Graceful systemd shutdown |

## Project Structure

```
codedeploy-service/
├── README.md                          # This file
├── main.tf                            # Root Terraform configuration
│
├── child-module/                      # Terraform child modules
│   ├── ec2/
│   │   ├── main.tf                   # EC2 instance resource + CodeDeploy agent setup
│   │   ├── variables.tf              # Input variables
│   │   ├── outputs.tf                # Output values (instance ID, IPs)
│   │   └── iam.tf                    # IAM role & instance profile
│   │
│   └── codedeploy/
│       ├── main.tf                   # CodeDeploy app & deployment group
│       ├── variables.tf              # Input variables
│       └── outputs.tf                # Output values
│
└── sample-app/                        # Node.js Application
    ├── package.json                  # Dependencies
    ├── server.js                      # Main Express server
    ├── appspec.yml                    # CodeDeploy lifecycle configuration
    ├── sample-app.service             # Systemd service unit file
    │
    └── scripts/
        ├── install_dependencies.sh    # Install Node/npm via NVM & setup systemd
        ├── start_server.sh            # Enable and start systemd service
        ├── stop_server.sh             # Stop systemd service gracefully
        └── validate_service.sh        # Verify service health
```

## Quick Start

### Prerequisites
- AWS Account with appropriate permissions
- Terraform installed (v1.0+)
- AWS CLI configured with credentials
- SSH key pair created in AWS (for EC2 access)

### Step 1: Initialize Terraform
```bash
cd /home/deepa/project/cloud-deployment-platform/EC2/codedeploy-service
terraform init
```

### Step 2: Review and Apply Terraform
```bash
terraform plan  # Review changes
terraform apply # Deploy infrastructure
```

This creates:
- EC2 instance with CodeDeploy agent
- CodeDeploy application & deployment group
- IAM roles and instance profile
- S3 bucket for deployment artifacts

### Step 2.5: Create/Verify S3 Bucket (if missing)

If the S3 bucket is not automatically created by Terraform, manually create it using AWS CLI:

```bash
# Create S3 bucket for deployment artifacts
BUCKET_NAME="my-codedeploy-bucket-$(date +%s)"
aws s3 mb s3://${BUCKET_NAME} --region us-east-1

# Enable versioning (optional but recommended)
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled

# Block public access (security best practice)
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Verify bucket was created
aws s3 ls | grep ${BUCKET_NAME}

# Save bucket name for use in Step 3
echo "Your S3 Bucket: ${BUCKET_NAME}"
```

**Note:** The EC2 instance IAM role must have `s3:GetObject` permission to pull deployment artifacts from this bucket.

### Step 3: Deploy Application
```bash
# Repackage the sample app
cd sample-app
tar -czf ../sample-app.tar.gz .

# Upload to S3
aws s3 cp ../sample-app.tar.gz s3://${BUCKET_NAME}/

# Create deployment
aws deploy create-deployment \
  --application-name my-app \
  --deployment-group-name my-deployment-group \
  --s3-location bucket=${BUCKET_NAME},key=sample-app.tar.gz,bundleType=tar
```

### Step 4: Monitor Deployment
```bash
aws deploy get-deployment --deployment-id d-XXXXX --query 'deploymentInfo.status'
```

### Step 5: Access the Application
```bash
curl http://<EC2-PUBLIC-IP>:3000/
curl http://<EC2-PUBLIC-IP>:3000/health
```

## Deployment Lifecycle

CodeDeploy executes the following lifecycle hooks during each deployment:

1. **ApplicationStop** → Stops the systemd service running Node.js
2. **DownloadBundle** → Downloads application code from S3
3. **BeforeInstall** → Installs Node.js, dependencies via NVM, and sets up systemd service
4. **Install** → Copies application files to `/var/www/sample-app` and service file
5. **AfterInstall** → (Optional) Post-install tasks
6. **ApplicationStart** → Enables and starts the systemd service
7. **ValidateService** → Verifies service is running and checks `/health` endpoint

## Systemd Service Management

### Service File: sample-app.service

Located at `/etc/systemd/system/sample-app.service`, configured with:
- **User:** ubuntu (non-root execution)
- **Type:** simple (standard long-running service)
- **Restart Policy:** Always restart on failure (5-second delay)
- **Working Directory:** `/var/www/sample-app`
- **Log Output:** `/var/log/sample-app/app.log` and `error.log`
- **Resource Limits:** 512MB memory, 50% CPU quota

### Managing the Service

```bash
# Check service status
sudo systemctl status sample-app.service

# View service logs
sudo journalctl -u sample-app.service -f

# View application output logs
sudo tail -f /var/log/sample-app/app.log
sudo tail -f /var/log/sample-app/error.log

# Start/Stop/Restart service
sudo systemctl start sample-app.service
sudo systemctl stop sample-app.service
sudo systemctl restart sample-app.service

# Enable/Disable auto-start on boot
sudo systemctl enable sample-app.service
sudo systemctl disable sample-app.service

# Check if service enabled on boot
sudo systemctl is-enabled sample-app.service
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Account                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐         ┌──────────────────────────────┐  │
│  │   S3 Bucket      │         │    EC2 Instance (Ubuntu)    │  │
│  │                  │────────▶│                              │  │
│  │ sample-app.tar.  │ Deploy  │  ┌──────────────────────┐   │  │
│  │ gz               │ Trigger │  │  CodeDeploy Agent    │   │  │
│  └──────────────────┘         │  │  - Pulls code from S3│   │  │
│                               │  │  - Runs lifecycle    │   │  │
│  ┌──────────────────┐         │  │    hooks             │   │  │
│  │  CodeDeploy      │────────▶│  ├──────────────────────┤   │  │
│  │  Service         │         │  │ Systemd Service      │   │  │
│  │                  │         │  │  - Node.js App       │   │  │
│  └──────────────────┘         │  │  - Auto-restart      │   │  │
│                               │  │  - Port 3000         │   │  │
│  ┌──────────────────┐         │  └──────────────────────┘   │  │
│  │  IAM Roles       │────────▶│                              │  │
│  │  - CodeDeploy    │         │  Public IP: 98.81.108.69    │  │
│  │  - EC2 Instance  │         │  Public DNS: ec2-xx-xx      │  │
│  └──────────────────┘         └──────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration

### main.tf
Core configuration calling EC2 and CodeDeploy modules:
- EC2 instance settings (AMI, instance type, key pair)
- CodeDeploy application name & deployment group
- CloudWatch monitoring (optional)

### Terraform Variables
All default values are set in `child-module/*/variables.tf`. To customize:

```bash
terraform apply -var="instance_type=t3.small" -var="ami=ami-xxxxxxxx"
```

## Benefits of Systemd Service Approach

✅ **Automatic Restarts** - Service automatically restarts if it crashes  
✅ **Process Management** - Centralized control via systemctl  
✅ **Logging** - Structured logging to journalctl + file-based logs  
✅ **Boot Persistence** - Service auto-starts on EC2 instance reboot  
✅ **Resource Limits** - Memory and CPU quotas configured  
✅ **Clean Shutdowns** - Graceful service termination during deployments  
✅ **Production Ready** - Standard Linux service management  

## Troubleshooting

### Service fails to start

```bash
# Check service status and error logs
sudo systemctl status sample-app.service
sudo journalctl -u sample-app.service -n 50 --no-pager

# Check systemd configuration
sudo systemctl cat sample-app.service
```

### Application not accessible

```bash
# Verify service is running
sudo systemctl is-active sample-app.service

# Check health endpoint
curl -v http://localhost:3000/health

# Verify security group allows port 3000
```

### Check application logs

```bash
# View real-time logs
sudo tail -f /var/log/sample-app/app.log
sudo tail -f /var/log/sample-app/error.log

# View all systemd logs for the service
sudo journalctl -u sample-app.service -f
```

## Key Differences from Original Setup

| Aspect | Old Approach | New Approach |
|--------|-------------|------------|
| Process Management | Manual script execution | Systemd service |
| Availability | Must monitor externally | Built-in restart policy |
| Persistence | Lost on reboot | Auto-starts on boot |
| Logging | Only file-based | Journalctl + files |
| Resource Control | None | Memory/CPU limits |
| Graceful Shutdown | Kill signals | Systemd termination |

## Future Enhancements

Consider these for production deployments:

1. **CloudWatch Integration** - Monitor service health and logs
2. **Auto-Scaling** - Use ASG with CodeDeploy for multiple instances
3. **Blue-Green Deployment** - Zero-downtime deployments
4. **Load Balancer** - ALB/NLB for traffic distribution
5. **Health Checks** - CloudWatch alarms on service failures
6. **Multi-Region** - Replicate infrastructure across regions
