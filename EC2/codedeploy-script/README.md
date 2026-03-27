v# CodeDeploy Infrastructure & Application

## Project Overview

This project implements a complete **CI/CD pipeline** using AWS services to automatically deploy a Node.js application to EC2 instances. It combines Terraform infrastructure-as-code with AWS CodeDeploy for automated application deployments.

### Key Features
- ✅ Infrastructure as Code (Terraform)
- ✅ Automated EC2 instance provisioning
- ✅ CodeDeploy for continuous deployment
- ✅ IAM roles and policies for secure access
- ✅ Auto-scaling ready with CodeDeploy configuration
- ✅ Zero-touch deployment with lifecycle hooks
- ✅ Health check validation
- ✅ Supports both Amazon Linux 2 and Ubuntu

## Project Structure

```
/home/deepa/project/cloud-deployment-platform/EC2/codedeploy-script/
├── README.md                          # This file
├── app.md                             # Application code explanation
├── issues.md                          # Detailed issue documentation
├── main.tf                            # Root Terraform configuration
├── terraform.tfstate                  # Terraform state file
│
├── child-module/                      # Terraform child modules
│   ├── ec2/
│   │   ├── main.tf                   # EC2 instance resource + NVM setup
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
    │
    └── scripts/
        ├── install_dependencies.sh    # Install Node/npm via NVM
        ├── start_server.sh            # Start the application
        ├── stop_server.sh             # Stop the application
        └── validate_service.sh        # Health check validation
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
│  │  Service         │         │  │   /var/www/          │   │  │
│  │                  │         │  │    sample-app/       │   │  │
│  └──────────────────┘         │  │                      │   │  │
│                               │  │  Node.js Express     │   │  │
│  ┌──────────────────┐         │  │  Server (Port 3000)  │   │  │
│  │  IAM Roles       │────────▶│  └──────────────────────┘   │  │
│  │  - CodeDeploy    │         │                              │  │
│  │  - EC2 Instance  │         │  Public IP: 98.81.108.69    │  │
│  └──────────────────┘         └──────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## How to Run

### Prerequisites
- AWS Account with appropriate permissions
- Terraform installed (v1.0+)
- AWS CLI configured with credentials
- SSH key pair created in AWS (for EC2 access)

### Step 1: Initialize Terraform
```bash
cd /home/deepa/project/cloud-deployment-platform/EC2/codedeploy-script
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

If the S3 bucket doesn't exist then manually create it using AWS CLI:

```bash
# Create S3 bucket for deployment artifacts
BUCKET_NAME="my-codedeploy-bucket-$(date +%s)"
aws s3 mb s3://${BUCKET_NAME} --region us-east-1

# Verify bucket was created
aws s3 ls | grep ${BUCKET_NAME}

```

**Note:** The EC2 instance IAM role must have `s3:GetObject` and `s3:GetObjectVersion` permissions to pull deployment artifacts from this bucket.

### Why EC2 Server Needs S3 Bucket Access

The EC2 instance requires S3 bucket access for the following critical reasons:

1. **CodeDeploy Agent Retrieval**
   - The CodeDeploy agent running on EC2 automatically downloads the application bundle (`.tar.gz`) from S3
   - This happens during the `DownloadBundle` lifecycle phase
   - Without S3 access, CodeDeploy agent cannot fetch your application code

2. **Autonomous Deployment Process**
   - The deployment is initiated by CodeDeploy service, not a human operator
   - The EC2 instance itself must authenticate to S3 using its IAM role
   - This eliminates the need for hardcoded AWS credentials on the instance

3. **Security Best Practice**
   - Using IAM roles is more secure than storing credentials in config files
   - The IAM role is automatically assumed by the EC2 instance
   - Follows the principle of least privilege (only S3 read access needed)

4. **Complete Deployment Flow**
   ```
   AWS CodeDeploy Service
         ↓
   Triggers EC2 CodeDeploy Agent
         ↓
   Agent uses EC2 IAM Role to authenticate
         ↓
   Downloads app bundle from S3 using EC2's temporary credentials
         ↓
   Executes lifecycle scripts (install, start, validate)
   ```



### Step 3: Deploy Application
```bash
# Repackage the sample app
cd sample-app
tar -czf ../sample-app.tar.gz .

# Upload to S3
aws s3 cp ../sample-app.tar.gz s3://my-codedeploy-bucket-<timestamp>/

# Create deployment
aws deploy create-deployment \
  --application-name my-app \
  --deployment-group-name my-deployment-group \
  --s3-location bucket=my-codedeploy-bucket-<timestamp>,key=sample-app.tar.gz,bundleType=tar
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

1. **ApplicationStop** → Stops running Node.js process
2. **DownloadBundle** → Downloads application code from S3
3. **BeforeInstall** → Installs Node.js & dependencies via NVM
4. **Install** → Copies application files to `/var/www/sample-app`
5. **AfterInstall** → (Optional) Post-install tasks
6. **ApplicationStart** → Starts Node.js server with npm
7. **ValidateService** → Checks `/health` endpoint to confirm app is running

## Configuration

### main.tf
Core configuration calling EC2 and CodeDeploy modules:
- EC2 instance settings (AMI, instance type, key pair)
- CodeDeploy application name & deployment group
- S3 bucket for artifact storage

### Terraform Variables
All default values are set in `child-module/*/variables.tf`. To customize:

```bash
terraform apply -var="instance_type=t3.small" -var="ami=ami-xxxxxxxx"
```

## S3 Bucket Structure

```
s3://my-codedeploy-bucket-<timestamp>/
└── sample-app.tar.gz          # Application deployment package
```

## Important Notes

### Downtime During Deployments
- **Current setup (1 instance):** ~30-90 seconds of downtime per deployment
- Application stops during `ApplicationStop` → `Install` stages
- For zero-downtime, implement Blue/Green deployment (requires 2+ instances)

### Region
- Default region: `us-east-1`
- To change: Update `provider "aws"` block in `main.tf`

### Security Considerations
- Security group allows inbound on port 3000 (update as needed)
- IAM roles follow least-privilege principle
- EC2 instance profile grants S3 read access for CodeDeploy artifacts

## Troubleshooting

### Common Issues

**Deployment fails with "Missing credentials"**
- EC2 instance lacks IAM instance profile
- Solution: Attach IAM role with `AmazonSSMManagedInstanceCore` + `AmazonS3ReadOnlyAccess`

**CodeDeploy agent not running**
- Check: `sudo systemctl status codedeploy-agent`
- Restart: `sudo systemctl restart codedeploy-agent`

**Application not accessible**
- Verify security group allows port 3000 inbound
- Check app logs: `sudo tail -f /tmp/sample-app.log`

See [issues.md](issues.md) for detailed issue resolution.

## Updating the Application

1. Make code changes in `sample-app/`
2. Repackage: `tar -czf ../sample-app.tar.gz .`
3. Upload to S3: `aws s3 cp ../sample-app.tar.gz s3://...`
4. Create new deployment (see Step 3 above)
5. Monitor and verify

## Cleanup

To destroy all infrastructure:
```bash
terraform destroy
```

This removes:
- EC2 instance
- CodeDeploy resources
- IAM roles and policies
- (Note: S3 bucket is retained for safety)

## References

- [AWS CodeDeploy Documentation](https://docs.aws.amazon.com/codedeploy/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AppSpec Reference](https://docs.aws.amazon.com/codedeploy/latest/userguide/application-revision-structure.html)
