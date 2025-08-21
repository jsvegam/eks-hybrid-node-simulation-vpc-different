# vpc-peering.tf (archivo único y completo)
module "hybrid_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.eks_cluster_name}-hybrid-vpc"
  cidr = "192.168.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["192.168.1.0/24", "192.168.2.0/24"]
  public_subnets  = ["192.168.101.0/24", "192.168.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    "eks-hybrid" = "true"
    "Terraform"  = "true"
    "Environment" = "test"
  })

  private_subnet_tags = {
    "Tier" = "Private"
    "kubernetes.io/role/internal-elb" = "1"
  }

  public_subnet_tags = {
    "Tier" = "Public"
    "kubernetes.io/role/elb" = "1"
  }
}

# VPC Peering connection
resource "aws_vpc_peering_connection" "cluster_hybrid" {
  vpc_id      = module.vpc.vpc_id
  peer_vpc_id = module.hybrid_vpc.vpc_id
  auto_accept = true

  tags = merge(var.tags, {
    Name        = "${var.eks_cluster_name}-peering"
    Source      = "eks-cluster"
    Destination = "hybrid-node"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Route table updates for VPC peering - FROM EKS TO HYBRID
resource "aws_route" "to_hybrid_from_eks_private" {
  count = length(module.vpc.private_route_table_ids)

  route_table_id            = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.hybrid_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster_hybrid.id

  timeouts {
    create = "5m"
  }

  depends_on = [aws_vpc_peering_connection.cluster_hybrid]
}

resource "aws_route" "to_hybrid_from_eks_public" {
  count = length(module.vpc.public_route_table_ids)

  route_table_id            = module.vpc.public_route_table_ids[count.index]
  destination_cidr_block    = module.hybrid_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster_hybrid.id

  timeouts {
    create = "5m"
  }

  depends_on = [aws_vpc_peering_connection.cluster_hybrid]
}

# Security group rules para permitir tráfico entre VPCs
resource "aws_security_group_rule" "eks_to_hybrid" {
  description              = "Allow traffic from EKS cluster to hybrid node"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = aws_security_group.hybrid_node.id

  depends_on = [aws_vpc_peering_connection.cluster_hybrid]
}

resource "aws_security_group_rule" "hybrid_to_eks" {
  description              = "Allow traffic from hybrid node to EKS cluster"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.hybrid_node.id
  security_group_id        = module.eks.cluster_security_group_id

  depends_on = [aws_vpc_peering_connection.cluster_hybrid]
}

