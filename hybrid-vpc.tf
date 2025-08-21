module "hybrid_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.eks_cluster_name}-hybrid-vpc"
  cidr = var.hybrid_vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = [cidrsubnet(var.hybrid_vpc_cidr, 8, 1), cidrsubnet(var.hybrid_vpc_cidr, 8, 2)]
  public_subnets  = [cidrsubnet(var.hybrid_vpc_cidr, 8, 101), cidrsubnet(var.hybrid_vpc_cidr, 8, 102)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    "eks-hybrid" = "true"
  })
}

# VPC Peering connection - DEPENDE de ambas VPCs
resource "aws_vpc_peering_connection" "cluster_hybrid" {
  vpc_id      = module.vpc.vpc_id
  peer_vpc_id = module.hybrid_vpc.vpc_id
  auto_accept = true

  tags = merge(var.tags, {
    Name = "${var.eks_cluster_name}-peering"
  })

  # DEPENDENCIAS EXPLÍCITAS
  depends_on = [
    module.vpc,
    module.hybrid_vpc
  ]
}

# Rutas DESDE EKS hacia Hybrid - DEPENDEN del peering
resource "aws_route" "to_hybrid_from_eks_private" {
  count = length(module.vpc.private_route_table_ids)

  route_table_id            = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.hybrid_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster_hybrid.id

  # DEPENDENCIAS EXPLÍCITAS
  depends_on = [
    aws_vpc_peering_connection.cluster_hybrid
  ]
}

resource "aws_route" "to_hybrid_from_eks_public" {
  count = length(module.vpc.public_route_table_ids)

  route_table_id            = module.vpc.public_route_table_ids[count.index]
  destination_cidr_block    = module.hybrid_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster_hybrid.id

  # DEPENDENCIAS EXPLÍCITAS
  depends_on = [
    aws_vpc_peering_connection.cluster_hybrid
  ]
}