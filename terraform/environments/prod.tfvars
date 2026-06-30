environment          = "prod"
aws_region           = "us-east-1"
aws_assume_role_arn  = "arn:aws:iam::222222222222:role/jenkins-terraform-prod"
okta_org_name        = "company"
okta_base_url        = "okta.com"
instance_type        = "t3.small"
instance_count       = 4
ami_id               = "ami-0123456789abcdef0"
vpc_id               = "vpc-0987654321fedcba0"
subnet_ids           = ["subnet-ccc333", "subnet-ddd444"]
allowed_ssh_cidrs    = []   # SSM only in prod, no direct SSH
okta_admin_group_users = [
  "ops-lead@company.com"
]
