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

# Toma el ID del AMI AL2023 desde SSM (x86_64)
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
  # provider = aws.virginia  # descomenta si tu instancia usa ese alias/región
}

# Versiones compatibles/recomendadas para tu versión de K8s (var.cluster_version)
data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "kubeproxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = var.cluster_version
  most_recent        = true
}



