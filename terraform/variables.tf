variable "environment" {
  description = "Deployment environment: dev, stage, or prod"
  type        = string
}

variable "aws_region" {
  description = "AWS region for EC2 resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_assume_role_arn" {
  description = "IAM role Jenkins assumes to run Terraform against AWS"
  type        = string
}

variable "okta_org_name" {
  description = "Okta org name, e.g. 'company' for company.okta.com"
  type        = string
}

variable "okta_base_url" {
  description = "Okta base domain: okta.com or oktapreview.com"
  type        = string
  default     = "okta.com"
}

variable "okta_api_token" {
  description = "Okta API token (SSWS) - sourced from Jenkins credentials"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type for application servers"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of EC2 instances to provision"
  type        = number
  default     = 2
}

variable "ami_id" {
  description = "AMI ID to launch (region-specific)"
  type        = string
}

variable "vpc_id" {
  description = "VPC where EC2 instances and security groups are created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs to spread instances across"
  type        = list(string)
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into instances (prefer SSM in prod)"
  type        = list(string)
  default     = []
}

variable "okta_admin_group_users" {
  description = "List of Okta user logins (emails) to add to the AWS admins Okta group"
  type        = list(string)
  default     = []
}
