#########################################
# VPC simple (pública/privada con NAT)
#########################################

module "vpc_virginia" {
  source    = "terraform-aws-modules/vpc/aws"
  version   = "5.0.0"


  name = "vpc-virginia"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

#########################################
# Módulo EKS propio (sin CAM aquí)
#########################################

module "eks" {
  source    = "./modules/eks"
  providers = { aws = aws.virginia }

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.28"

  vpc_id     = module.vpc_virginia.vpc_id
  subnet_ids = module.vpc_virginia.private_subnets

  # <<< AÑADE ESTO o usa los defaults del módulo >>>
  endpoint_public_access  = true
  endpoint_private_access = false

  desired_size   = 2
  max_size       = 3
  min_size       = 1
  instance_types = ["t3.small"]
  capacity_type  = "SPOT"
  disk_size      = 20

  tags = {
    Environment = "production"
  }
}