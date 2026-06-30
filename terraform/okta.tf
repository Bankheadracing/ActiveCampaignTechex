# --- Okta groups ----------------------------------------------------------

resource "okta_group" "aws_admins" {
  name        = "${var.environment}-aws-admins"
  description = "Users permitted to access the ${var.environment} AWS account via SSO"
}

resource "okta_group" "aws_readonly" {
  name        = "${var.environment}-aws-readonly"
  description = "Read-only AWS console access for ${var.environment}"
}

resource "okta_group_memberships" "aws_admins_members" {
  group_id = okta_group.aws_admins.id
  users    = [for login in var.okta_admin_group_users : okta_user.admin[login].id]
}

resource "okta_user" "admin" {
  for_each   = toset(var.okta_admin_group_users)
  first_name = "Pending"
  last_name  = "Invite"
  login      = each.value
  email      = each.value
  status     = "STAGED" # invited, not auto-activated by terraform
}

# --- Okta SAML app wired to AWS IAM Identity Center / AWS SSO -------------

resource "okta_app_saml" "aws_sso" {
  label                    = "AWS Account (${var.environment})"
  sso_url                  = "https://signin.aws.amazon.com/saml"
  recipient                = "https://signin.aws.amazon.com/saml"
  destination              = "https://signin.aws.amazon.com/saml"
  audience                 = "urn:amazon:webservices"
  subject_name_id_template = "$${user.email}"
  subject_name_id_format   = "urn:oasis:names:tc:SAML:2.0:nameid-format:unspecified"
  response_signed          = true
  signature_algorithm      = "RSA_SHA256"
}

resource "okta_app_group_assignment" "aws_admins_assignment" {
  app_id   = okta_app_saml.aws_sso.id
  group_id = okta_group.aws_admins.id
}

resource "okta_app_group_assignment" "aws_readonly_assignment" {
  app_id   = okta_app_saml.aws_sso.id
  group_id = okta_group.aws_readonly.id
}

# --- MFA / sign-on policy scoped to the AWS admins group ------------------

resource "okta_policy_signon" "aws_admin_signon" {
  name            = "${var.environment}-aws-admin-signon"
  status          = "ACTIVE"
  description     = "Require MFA for anyone accessing AWS through SSO"
  groups_included = [okta_group.aws_admins.id]
}

resource "okta_policy_rule_signon" "aws_admin_mfa_required" {
  policy_id           = okta_policy_signon.aws_admin_signon.id
  name                = "require-mfa"
  status              = "ACTIVE"
  mfa_required        = true
  mfa_prompt          = "ALWAYS"
  session_idle        = 30
  session_lifetime    = 720
  access              = "ALLOW"
}
