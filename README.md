# Cloud Deployment Platform

A comprehensive collection of Infrastructure as Code (IaC) templates and modules for deploying applications to AWS cloud infrastructure using Terraform.

## Overview

This platform provides ready-to-use Terraform configurations for AWS deployment patterns, focusing on:

- **EC2 with CodeDeploy**: Automated CI/CD pipelines for deploying applications to EC2 instances

## Project Structure

```
cloud-deployment-platform/
├── README.md                    # This overview document
└── EC2/                         # EC2-based deployments
    └── codedeploy-script/       # CodeDeploy infrastructure and sample app
        ├── README.md           # Detailed CodeDeploy documentation
        ├── app.md              # Application code explanation
        ├── deployment.md       # Deployment documentation
        ├── issues.md           # Known issues and solutions
        ├── main.tf             # Root Terraform configuration
        ├── child-module/       # Reusable Terraform modules
        │   ├── ec2/           # EC2 instance provisioning
        │   └── codedeploy/    # CodeDeploy application setup
        └── sample-app/         # Node.js sample application
            ├── appspec.yml     # CodeDeploy deployment specification
            ├── package.json    # Node.js dependencies
            ├── server.js       # Express.js web server
            ├── terraform.tfstate # Terraform state file
            └── scripts/        # Deployment lifecycle scripts
                ├── install_dependencies.sh
                ├── start_server.sh
                ├── stop_server.sh
                └── validate_service.sh
```

## Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- AWS account with necessary permissions

### Basic Usage

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd cloud-deployment-platform
   ```

2. **Navigate to the deployment module**
   ```bash
   cd EC2/codedeploy-script
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Review and customize variables**
   ```bash
   # Edit variables in main.tf or create terraform.tfvars
   terraform plan
   ```

5. **Deploy infrastructure**
   ```bash
   terraform apply
   ```

## Deployment Type

### EC2 with CodeDeploy

Automated deployment of applications to EC2 instances using AWS CodeDeploy.

**Features:**
- Auto-provisioned EC2 instances
- CodeDeploy application and deployment groups
- IAM roles and policies
- Sample Node.js application
- Deployment scripts and lifecycle hooks

**Location:** `EC2/codedeploy-script/`

## Sample Application

The platform includes a sample Node.js application for testing deployments:
- **Express.js Server**: Simple web server demonstrating CodeDeploy deployment

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Check the `EC2/codedeploy-script/README.md` for detailed documentation
- Review `issues.md` files for known issues and solutions
- Create an issue in the repository for bugs or feature requests

- **To-Do List App**: A JavaScript single-page application
- **Node.js Express Server**: Simple web server for CodeDeploy testing

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Check the individual module READMEs for detailed documentation
- Review `issues.md` files for known issues and solutions
- Create an issue in the repository for bugs or feature requests
