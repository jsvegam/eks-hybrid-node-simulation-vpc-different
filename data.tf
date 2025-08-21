# Availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# EKS cluster auth
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

# AWS caller identity
data "aws_caller_identity" "current" {}

# AWS partition
data "aws_partition" "current" {}

# AWS region
data "aws_region" "current" {}