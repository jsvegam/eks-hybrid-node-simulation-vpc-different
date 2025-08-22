############################################
# Rutas desde Hybrid VPC hacia EKS VPC
############################################
resource "aws_route" "hybrid_to_eks_private" {
  route_table_id            = module.hybrid_vpc.private_route_table_ids[0]
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster_hybrid.id

  depends_on = [aws_vpc_peering_connection.cluster_hybrid]
}

resource "aws_route" "hybrid_to_eks_public" {
  route_table_id            = module.hybrid_vpc.public_route_table_ids[0]
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.cluster_hybrid.id

  depends_on = [aws_vpc_peering_connection.cluster_hybrid]
}
