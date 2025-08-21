# manual-routes.tf
# Este archivo contiene las rutas que se crearán MANUALMENTE después

# Outputs para facilitar la configuración manual
output "manual_route_instructions" {
  description = "Instructions for manual route configuration"
  value       = <<-EOT
    Para completar la configuración de red, ejecuta estos comandos MANUALMENTE:

    # Rutas desde Hybrid VPC hacia EKS VPC
    aws ec2 create-route \
      --route-table-id ${join(", ", module.hybrid_vpc.private_route_table_ids)} \
      --destination-cidr-block ${module.vpc.vpc_cidr_block} \
      --vpc-peering-connection-id ${aws_vpc_peering_connection.cluster_hybrid.id} \
      --profile eks-operator

    aws ec2 create-route \
      --route-table-id ${join(", ", module.hybrid_vpc.public_route_table_ids)} \
      --destination-cidr-block ${module.vpc.vpc_cidr_block} \
      --vpc-peering-connection-id ${aws_vpc_peering_connection.cluster_hybrid.id} \
      --profile eks-operator

    Esto evita problemas de 'RouteAlreadyExists' y dependencias circulares.
  EOT
}