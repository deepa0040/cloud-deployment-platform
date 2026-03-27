resource "aws_instance" "this" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  vpc_security_group_ids = var.security_group_ids

  tags = merge(
    {
      Name = "CodeDeploy-EC2"
    },
    var.tags
  )

  # User data to install CodeDeploy agent (supports both Amazon Linux and Ubuntu)
  user_data = base64encode(<<-EOF
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
    else
      echo "Unsupported OS: $OS"
      exit 1
    fi
    
    # Download and install CodeDeploy agent
    cd $HOME_DIR
    wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
    chmod +x ./install
    ./install auto
    systemctl start codedeploy-agent
    systemctl enable codedeploy-agent
  EOF
  )
}
