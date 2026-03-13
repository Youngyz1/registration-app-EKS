output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_db_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for Terraform state — paste this into backend.tf"
  value       = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for state locking — paste this into backend.tf"
  value       = aws_dynamodb_table.tfstate_lock.name
}

output "backend_config_snippet" {
  description = "Copy this block into your main terraform/backend.tf"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.tfstate.bucket}"
        key            = "registration-app/terraform.tfstate"
        region         = "${var.aws_region}"
        dynamodb_table = "${aws_dynamodb_table.tfstate_lock.name}"
        encrypt        = true
      }
    }
  EOT
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler — use in Helm values"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "velero_bucket_name" {
  description = "S3 bucket name for Velero backups"
  value       = aws_s3_bucket.velero.bucket
}

output "velero_role_arn" {
  description = "IAM role ARN for Velero — use in Helm values"
  value       = aws_iam_role.velero.arn
}