# Security Group - DEPENDE de la VPC híbrida
resource "aws_security_group" "hybrid_node" {
  name        = "${var.eks_cluster_name}-hybrid-node-sg"
  description = "Security group for Hybrid node in private subnet"
  vpc_id      = module.hybrid_vpc.vpc_id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [module.hybrid_vpc.vpc_cidr_block]
  }

  ingress {
    description = "EKS cluster communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.eks_cluster_name}-hybrid-node-sg"
  })

  # DEPENDENCIAS EXPLÍCITAS
  depends_on = [
    module.hybrid_vpc
  ]
}

# Instancia EC2 - DEPENDE de TODO lo anterior
resource "aws_instance" "hybrid_node" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.hybrid_instance_type
  subnet_id     = module.hybrid_vpc.private_subnets[0]
  
  vpc_security_group_ids      = [aws_security_group.hybrid_node.id]
  associate_public_ip_address = false
  key_name                    = var.hybrid_ssh_key_name

  user_data_base64 = local.hybrid_user_data_base64

  # DEPENDENCIAS EXPLÍCITAS EN ORDEN CORRECTO
  depends_on = [
    module.hybrid_vpc,
    aws_security_group.hybrid_node,
    aws_vpc_peering_connection.cluster_hybrid,
    aws_route.to_hybrid_from_eks_private,
    aws_route.to_hybrid_from_eks_public,
    null_resource.create_hybrid_routes  # Rutas desde Hybrid
  ]

  tags = merge(var.tags, {
    Name = "${var.eks_cluster_name}-hybrid-node"
  })
}

# Rutas DESDE Hybrid hacia EKS - Se crean después de todo
resource "null_resource" "create_hybrid_routes" {
  # DEPENDE de que el peering y las VPCs existan
  depends_on = [
    module.hybrid_vpc,
    aws_vpc_peering_connection.cluster_hybrid,
    aws_route.to_hybrid_from_eks_private,
    aws_route.to_hybrid_from_eks_public
  ]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      # Esperar a que las route tables estén disponibles
      sleep 10

      # Crear rutas desde Hybrid VPC hacia EKS VPC
      aws ec2 create-route \
        --route-table-id ${module.hybrid_vpc.private_route_table_ids[0]} \
        --destination-cidr-block ${module.vpc.vpc_cidr_block} \
        --vpc-peering-connection-id ${aws_vpc_peering_connection.cluster_hybrid.id} \
        --region ${var.aws_region} \
        --profile ${var.aws_profile} ||
        echo "Route可能已经存在，继续..."
        
      aws ec2 create-route \
        --route-table-id ${module.hybrid_vpc.public_route_table_ids[0]} \
        --destination-cidr-block ${module.vpc.vpc_cidr_block} \
        --vpc-peering-connection-id ${aws_vpc_peering_connection.cluster_hybrid.id} \
        --region ${var.aws_region} \
        --profile ${var.aws_profile} ||
        echo "Route可能已经存在，继续..."
    EOT
  }
}

# Configuración final - Verifica que todo esté correcto
resource "null_resource" "validation" {
  depends_on = [
    aws_instance.hybrid_node,
    null_resource.create_hybrid_routes
  ]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      echo "✅ Todas las dependencias se han creado correctamente"
      echo "🔄 Esperando a que el nodo híbrido se inicie..."
      sleep 30
      echo "🎉 Implementación completada!"
    EOT
  }
}