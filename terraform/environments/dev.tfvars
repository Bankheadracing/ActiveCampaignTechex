environment          = "dev"
aws_region           = "us-east-1"
aws_assume_role_arn  = "arn:aws:iam::111111111111:role/jenkins-terraform-dev"
okta_org_name        = "company-dev"
okta_base_url        = "oktapreview.com"
instance_type        = "t3.micro"
instance_count       = 2
ami_id               = "ami-0123456789abcdef0"
vpc_id               = "vpc-0123456789abcdef0"
subnet_ids           = ["subnet-aaa111", "subnet-bbb222"]
allowed_ssh_cidrs    = ["10.0.0.0/8"]
okta_admin_group_users = [
  "jane.doe@company.com"
]
