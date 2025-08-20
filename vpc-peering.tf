# VPC Peering between cluster VPC and Hybrid VPC
resource "aws_vpc_peering_connection" "cluster_hybrid" {
  vpc_id        = module.vpc.vpc_id
  peer_vpc_id   = module.hybrid_vpc.vpc_id
  auto_accept   = true
  tags = merge(var.tags, {
    Name = "${var.eks_cluster_name}-cluster-hybrid-peering"
  })
}

# Routes in Cluster VPC to reach Hybrid VPC
resource "aws_route" "cluster_to_hybrid" {
  for_each               = { for rt in module.vpc.private_route_table_ids : rt => rt }
  route_table_id         = each.value
  destination_cidr_block = var.hybrid_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster_hybrid.id
}

# Routes in Hybrid VPC to reach Cluster VPC
resource "aws_route" "hybrid_to_cluster" {
  for_each               = { for rt in module.hybrid_vpc.public_route_table_ids : rt => rt }
  route_table_id         = each.value
  destination_cidr_block = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster_hybrid.id
}