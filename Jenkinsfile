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
    TF_IN_AUTOMATION = 'true'
    TF_WORKSPACE_DIR = 'terraform'
    AWS_DEFAULT_REGION = 'us-east-1'
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
