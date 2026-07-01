environment          = "dev"
aws_account_id       = "034362051932"
aws_region           = "us-east-1"
aws_assume_role_arn  = "arn:aws:iam::111111111111:role/jenkins-terraform-dev"
okta_org_name        = "integrator-6065233"
okta_base_url        = "okta.com"
instance_type        = "t3.micro"
instance_count       = 1
ami_id               = "ami-06067086cf86c58e6"
vpc_id               = "vpc-0764d96120180b4ec"
subnet_ids           = ["subnet-003be93b4f92f6640", "subnet-040e0f2c5a99bdf7b"]
allowed_ssh_cidrs    = ["10.0.0.0/8"]
okta_admin_group_users = [
  "rmart113@students.kennesaw.edu"
]
