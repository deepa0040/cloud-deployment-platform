variable "application_name" {
  description = "Name of the CodeDeploy application"
  type        = string
  default     = "my-app"
}

variable "deployment_group_name" {
  description = "Name of the deployment group"
  type        = string
  default     = "my-deployment-group"
}

variable "ec2_tag_key" {
  description = "Tag key for EC2 instances"
  type        = string
  default     = "Name"
}

variable "ec2_tag_value" {
  description = "Tag value for EC2 instances"
  type        = string
  default     = "CodeDeploy-EC2"
}