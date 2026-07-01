provider "aws" {
  region = var.aws_region

  # Jenkins assumes this role via OIDC/instance profile - no long-lived keys in the repo.
  assume_role {
    role_arn = var.aws_assume_role_arn
  }

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Pipeline    = "jenkins-okta-ec2"
      Environment = var.environment
    }
  }
}

provider "okta" {
  org_name  = var.okta_org_name   # e.g. "company"
  base_url  = var.okta_base_url   # e.g. "okta.com" or "oktapreview.com"
  api_token = var.okta_api_token  # injected from Jenkins credentials, never hardcoded
}
