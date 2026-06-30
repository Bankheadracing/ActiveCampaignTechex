output "instance_ids" {
  description = "IDs of provisioned EC2 instances"
  value       = aws_instance.app[*].id
}

output "instance_private_ips" {
  value = aws_instance.app[*].private_ip
}

output "okta_aws_sso_app_id" {
  value = okta_app_saml.aws_sso.id
}

output "okta_admin_group_id" {
  value = okta_group.aws_admins.id
}
