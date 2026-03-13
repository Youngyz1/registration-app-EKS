# ============================================
# REMOTE STATE BACKEND
#
# IMPORTANT: Run terraform/bootstrap/ FIRST to
# create this bucket and table, then copy the
# actual bucket name from bootstrap outputs.
#
# After adding this file, run:
#   terraform init -migrate-state
# to migrate any existing local state to S3.
# ============================================

terraform {
  backend "s3" {
    bucket       = "registration-app-eks-tfstate-958421185668"
    key          = "registration-app/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

