# IAM role for EC2 instance to allow CodeDeploy and S3 access
resource "aws_iam_role" "ec2_codedeploy_role" {
  name = "EC2-CodeDeploy-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policy for CodeDeploy
resource "aws_iam_role_policy_attachment" "ec2_codedeploy_policy" {
  role       = aws_iam_role.ec2_codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach AWS managed policy for S3 access (needed for CodeDeploy to pull artifacts)
resource "aws_iam_role_policy_attachment" "ec2_s3_policy" {
  role       = aws_iam_role.ec2_codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Create instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2-CodeDeploy-Profile"
  role = aws_iam_role.ec2_codedeploy_role.name
}
