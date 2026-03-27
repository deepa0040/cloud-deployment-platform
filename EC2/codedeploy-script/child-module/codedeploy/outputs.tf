output "application_name" {
  description = "Name of the CodeDeploy application"
  value       = aws_codedeploy_app.this.name
}

output "deployment_group_name" {
  description = "Name of the deployment group"
  value       = aws_codedeploy_deployment_group.this.deployment_group_name
}

output "service_role_arn" {
  description = "ARN of the CodeDeploy service role"
  value       = aws_iam_role.codedeploy_service_role.arn
}