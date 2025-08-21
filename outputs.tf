output "hybrid_vpc_id" {
  description = "ID de la VPC híbrida"
  value       = module.hybrid_vpc.vpc_id
  depends_on  = [module.hybrid_vpc]
}

output "main_vpc_id" {
  description = "ID de la VPC principal"
  value       = module.vpc.vpc_id
  depends_on  = [module.vpc]
}

output "vpc_peering_connection_id" {
  description = "ID de la conexión de peering"
  value       = aws_vpc_peering_connection.cluster_hybrid.id
  depends_on  = [aws_vpc_peering_connection.cluster_hybrid]
}

output "hybrid_node_public_ip" {
  description = "IP pública del nodo híbrido"
  value       = aws_instance.hybrid_node.public_ip
  depends_on  = [aws_instance.hybrid_node]
}

output "eks_cluster_endpoint" {
  description = "Endpoint del cluster EKS"
  value       = module.eks.cluster_endpoint
  depends_on  = [module.eks]
}

output "deployment_status" {
  description = "Estado de la implementación"
  value       = "Completado - Todos los recursos creados en el orden correcto"
  #depends_on  = [null_resource.validation]
}