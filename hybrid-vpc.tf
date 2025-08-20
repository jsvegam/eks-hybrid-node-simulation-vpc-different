module "hybrid_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1"

  name = "${var.eks_cluster_name}-hybrid-vpc"
  cidr = var.hybrid_vpc_cidr

  azs              = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets   = var.hybrid_public_subnets
  enable_nat_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Internet GW so the hybrid node can reach SSM/ECR/EKS public endpoints (or route via peering)
  create_igw = true

  tags = merge(var.tags, {
    "eks-hybrid" = "true"
  })
}