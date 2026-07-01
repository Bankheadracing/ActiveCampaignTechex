/*
 Jenkins CI/CD pipeline for managing Okta + AWS EC2 via Terraform.
 No CloudFormation - Terraform is the single source of truth for both
 the AWS (EC2) and Okta provider resources, applied together so they
 never drift relative to each other (e.g. an EC2 fleet and the Okta
 SSO app/group that grants access to it).
*/

pipeline {
  agent any

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'stage', 'prod'], description: 'Target environment')
    booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Skip manual approval gate (dev only - ignored for stage/prod)')
    booleanParam(name: 'DESTROY', defaultValue: false, description: 'Run terraform destroy instead of apply')
  }

  environment {
    TF_IN_AUTOMATION   = 'true'
    TF_WORKSPACE_DIR   = 'terraform'
    AWS_DEFAULT_REGION = 'us-east-1'
    // Pinned tool versions — bump these here to upgrade across all environments
    TERRAFORM_VERSION  = '1.8.5'
    TFLINT_VERSION     = 'v0.51.1'
    CHECKOV_VERSION    = '3.2.0'
  }

  options {
    timestamps()
    disableConcurrentBuilds() // one plan/apply at a time per state file
    timeout(time: 45, unit: 'MINUTES')
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    // ── NEW: install every CLI tool the pipeline needs if not already present ──
    // This lets the pipeline run on a plain Jenkins agent (agent any) without
    // any pre-baked Docker image or manual server setup.
    stage('Install Tools') {
      steps {
        sh '''
          set -e

          # ── Terraform ──────────────────────────────────────────────────────
          if ! command -v terraform &>/dev/null; then
            echo ">>> Installing Terraform ${TERRAFORM_VERSION}..."
            apt-get update -qq && apt-get install -y -qq unzip curl
            curl -fsSL \
              "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
              -o /tmp/terraform.zip
            unzip -q /tmp/terraform.zip -d /usr/local/bin/
            chmod +x /usr/local/bin/terraform
            rm /tmp/terraform.zip
          else
            echo ">>> Terraform already installed: $(terraform version -json | python3 -c 'import sys,json; print(json.load(sys.stdin)[\"terraform_version\"])')"
          fi

          # ── tflint ─────────────────────────────────────────────────────────
          if ! command -v tflint &>/dev/null; then
            echo ">>> Installing tflint ${TFLINT_VERSION}..."
            curl -fsSL \
              "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_amd64.zip" \
              -o /tmp/tflint.zip
            unzip -q /tmp/tflint.zip -d /usr/local/bin/
            chmod +x /usr/local/bin/tflint
            rm /tmp/tflint.zip
          else
            echo ">>> tflint already installed: $(tflint --version)"
          fi

          # ── checkov (via pip3) ─────────────────────────────────────────────
          if ! command -v checkov &>/dev/null; then
            echo ">>> Installing checkov ${CHECKOV_VERSION}..."
            apt-get install -y -qq python3-pip
            pip3 install --quiet "checkov==${CHECKOV_VERSION}"
          else
            echo ">>> checkov already installed: $(checkov --version)"
          fi

          # ── jq (used in Post-Apply Verification) ──────────────────────────
          if ! command -v jq &>/dev/null; then
            echo ">>> Installing jq..."
            apt-get install -y -qq jq
          else
            echo ">>> jq already installed: $(jq --version)"
          fi

          # ── AWS CLI v2 (used in Post-Apply Verification) ──────────────────
          if ! command -v aws &>/dev/null; then
            echo ">>> Installing AWS CLI v2..."
            apt-get install -y -qq curl unzip
            curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
            unzip -q /tmp/awscliv2.zip -d /tmp/
            /tmp/aws/install --update
            rm -rf /tmp/awscliv2.zip /tmp/aws
          else
            echo ">>> AWS CLI already installed: $(aws --version)"
          fi

          echo ""
          echo ">>> All tools verified:"
          terraform version
          tflint  --version
          checkov --version
          jq      --version
          aws     --version
        '''
      }
    }

    stage('Load Credentials') {
      steps {
        // AWS creds come from an assumed role (no static keys); Okta token from Jenkins secret store.
        withCredentials([
          string(credentialsId: "okta-api-token-${params.ENVIRONMENT}", variable: 'TF_VAR_okta_api_token'),
          string(credentialsId: "aws-assume-role-arn-${params.ENVIRONMENT}", variable: 'TF_VAR_aws_assume_role_arn')
        ]) {
          echo "Credentials loaded for ${params.ENVIRONMENT} (values masked)."
        }
      }
    }

    stage('Init') {
      steps {
        dir(env.TF_WORKSPACE_DIR) {
          sh """
            terraform init -input=false \
              -backend-config="key=okta-ec2/${params.ENVIRONMENT}/terraform.tfstate"
          """
        }
      }
    }

    stage('Validate & Lint') {
      steps {
        dir(env.TF_WORKSPACE_DIR) {
          sh 'terraform fmt -check -recursive'
          sh 'terraform validate'
          sh 'tflint --init && tflint'
          sh 'checkov -d . --quiet --compact || true' // policy/security scan, non-blocking warning
        }
      }
    }

    stage('Plan') {
      steps {
        dir(env.TF_WORKSPACE_DIR) {
          withCredentials([
            string(credentialsId: "okta-api-token-${params.ENVIRONMENT}", variable: 'TF_VAR_okta_api_token'),
            string(credentialsId: "aws-assume-role-arn-${params.ENVIRONMENT}", variable: 'TF_VAR_aws_assume_role_arn')
          ]) {
            script {
              def destroyFlag = params.DESTROY ? '-destroy' : ''
              sh """
                terraform plan -input=false ${destroyFlag} \
                  -var-file=environments/${params.ENVIRONMENT}.tfvars \
                  -out=tfplan-${params.ENVIRONMENT}.bin
                terraform show -no-color tfplan-${params.ENVIRONMENT}.bin > tfplan-${params.ENVIRONMENT}.txt
              """
            }
          }
        }
        archiveArtifacts artifacts: "${env.TF_WORKSPACE_DIR}/tfplan-${params.ENVIRONMENT}.txt", fingerprint: true
      }
    }

    stage('Manual Approval') {
      when {
        expression { params.ENVIRONMENT != 'dev' || !params.AUTO_APPROVE }
      }
      steps {
        script {
          def planText = readFile("${env.TF_WORKSPACE_DIR}/tfplan-${params.ENVIRONMENT}.txt")
          input message: "Review the Terraform plan for ${params.ENVIRONMENT}. Apply changes to EC2 and Okta?",
                parameters: [text(name: 'PlanSummary', defaultValue: planText.take(4000), description: 'Plan output (truncated)')]
        }
      }
    }

    stage('Apply') {
      steps {
        dir(env.TF_WORKSPACE_DIR) {
          withCredentials([
            string(credentialsId: "okta-api-token-${params.ENVIRONMENT}", variable: 'TF_VAR_okta_api_token'),
            string(credentialsId: "aws-assume-role-arn-${params.ENVIRONMENT}", variable: 'TF_VAR_aws_assume_role_arn')
          ]) {
            sh "terraform apply -input=false -auto-approve tfplan-${params.ENVIRONMENT}.bin"
          }
        }
      }
    }

    stage('Post-Apply Verification') {
      when {
        expression { !params.DESTROY }
      }
      steps {
        dir(env.TF_WORKSPACE_DIR) {
          sh '''
            echo "Checking EC2 instances are running..."
            for id in $(terraform output -json instance_ids | jq -r '.[]'); do
              aws ec2 wait instance-status-ok --instance-ids "$id"
            done

            echo "Confirming Okta SSO app is active..."
            APP_ID=$(terraform output -raw okta_aws_sso_app_id)
            curl -s -H "Authorization: SSWS ${TF_VAR_okta_api_token}" \
              "https://${OKTA_BASE_URL:-company.okta.com}/api/v1/apps/${APP_ID}" | jq -e '.status == "ACTIVE"'
          '''
        }
      }
    }
  }

  post {
    success {
      echo "Pipeline succeeded for ${params.ENVIRONMENT}."
      // slackSend / emailext notification hook goes here
    }
    failure {
      echo "Pipeline failed for ${params.ENVIRONMENT} - check console output and tfplan artifact."
    }
    always {
      archiveArtifacts artifacts: "${env.TF_WORKSPACE_DIR}/tfplan-${params.ENVIRONMENT}.bin", allowEmptyArchive: true
    }
  }
}
