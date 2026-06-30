terraform {
  required_version = ">= 1.6.0"

  # Remote state in S3 with DynamoDB locking - shared across Jenkins agents
  # so concurrent pipeline runs never corrupt state.
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "okta-ec2/terraform.tfstate" # overridden per-env via -backend-config in CI
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    okta = {
      source  = "okta/okta"
      version = "~> 4.0"
    }
  }
}
