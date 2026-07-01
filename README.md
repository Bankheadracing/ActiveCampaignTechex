# ActiveCampaignTechex

# Okta + AWS EC2 CI/CD Pipeline (Jenkins + Terraform)

This repo provisions and manages an Okta tenant (apps, groups, policies, users) and AWS EC2
infrastructure through a single Jenkins pipeline backed by Terraform. The AWS resources are managed with the Terraform AWS
provider, side by side with the Terraform Okta provider, in the same plan/apply lifecycle.

## Layout

```
terraform/
  backend.tf          # S3 + DynamoDB remote state
  providers.tf         # aws + okta provider blocks
  variables.tf          # shared input variables
  ec2.tf                # EC2 instances, SG, IAM instance profile
  okta.tf                # Okta groups, app, group rule, MFA policy
  outputs.tf
  environments/
    dev.tfvars
    prod.tfvars
Jenkinsfile             # Declarative pipeline: validate -> plan -> approve -> apply
```

## Pipeline flow

1. **Checkout** – pull this repo (Jenkins multibranch or webhook-triggered).
2. **Validate** – `terraform fmt -check`, `terraform validate`, `tflint`, `checkov` (policy/security scan).
3. **Plan** – `terraform plan` against the environment selected (`dev`/`stage`/`prod`), saved as an artifact.
4. **Manual approval** – required for `stage`/`prod`; `dev` can auto-apply.
5. **Apply** – `terraform apply` using the saved plan file (no drift between plan and apply).
6. **Post-apply verification** – smoke tests (EC2 reachability/SSM ping, Okta API check that the app/group exists).
7. **Notify** – Slack/email with plan summary and apply result; archive the plan + apply logs.

Credentials (AWS keys/role ARN, Okta API token) are stored in the Jenkins Credentials Store
(or Vault, if available) and injected as environment variables — never committed to the repo.

See the accompanying slide deck for the high-level architecture diagram and design rationale.
