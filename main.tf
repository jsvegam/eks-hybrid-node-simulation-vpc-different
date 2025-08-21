############################################
# VPC
############################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.eks_cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  })

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

############################################
# EKS (module v20)
############################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.cluster_version # (por defecto "1.29")

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }

  # IMPORTANTE: desactivar la entrada automática del "cluster_creator"
  # porque ya gestionas el mismo principal en access_entries (evita el 409).
  enable_cluster_creator_admin_permissions = false

  # Add-ons -> versión soportada dinámica (evita InvalidParameterException)
  cluster_addons = {
    coredns = {
      addon_version               = data.aws_eks_addon_version.coredns.version
      most_recent                 = false
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      addon_version = data.aws_eks_addon_version.kubeproxy.version
      most_recent   = false
    }
    vpc-cni = {
      addon_version               = data.aws_eks_addon_version.vpc_cni.version
      most_recent                 = false
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  # Access Entry para tu usuario (este ya lo importaste)
  access_entries = {
    eks-operator = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/eks-operator"
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  tags       = var.tags
  depends_on = [module.vpc]
}
