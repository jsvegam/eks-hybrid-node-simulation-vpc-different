############################################
# AMI Amazon Linux 2023 (x86_64)
############################################
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

############################################
# Security Group del nodo híbrido
############################################
resource "aws_security_group" "hybrid_node" {
  name        = "${var.eks_cluster_name}-hybrid-node-sg"
  description = "Security group for Hybrid node in private subnet"
  vpc_id      = module.hybrid_vpc.vpc_id

  # SSH desde la VPC híbrida (opcional)
  ingress {
    description = "SSH from Hybrid VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [module.hybrid_vpc.vpc_cidr_block]
  }

  # (Opcional) SSH desde tu IP pública
  dynamic "ingress" {
    for_each = var.ssh_ingress_cidr == "" ? [] : [var.ssh_ingress_cidr]
    content {
      description = "SSH from operator IP"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Comunicación desde la VPC del clúster (peering)
  ingress {
    description = "EKS cluster communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Salida total
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name         = "${var.eks_cluster_name}-hybrid-node-sg"
    "eks-hybrid" = "true"
    Tier         = "private"
  })
}

############################################
# User Data: SSM + nodeadm (escapes $${...})
############################################
locals {
  hybrid_user_data = <<-EOF
    #!/usr/bin/env bash
    set -euxo pipefail
    exec > >(tee /var/log/hybrid-bootstrap.log) 2>&1
    echo "[$(date)] Starting EKS Hybrid Node bootstrap"

    # Paquetes base con reintentos (dnf en AL2023)
    for i in {1..5}; do
      sudo dnf -y update && break || sleep 30
    done
    for i in {1..5}; do
      sudo dnf -y install amazon-ssm-agent tar curl jq && break || sleep 30
    done

    # SSM Agent: registro híbrido con activación
    sudo systemctl enable --now amazon-ssm-agent || true
    for i in {1..3}; do
      sudo /usr/bin/amazon-ssm-agent -register \
        -code '${aws_ssm_activation.hybrid.activation_code}' \
        -id '${aws_ssm_activation.hybrid.id}' \
        -region '${var.aws_region}' -y && break || sleep 10
    done
    sudo systemctl restart amazon-ssm-agent || true

    # Descargar nodeadm (varios mirrors)
    nodeadm_urls=(
      "https://hybrid-assets.regionless.eks.amazonaws.com/releases/latest/bin/linux/amd64/nodeadm"
      "https://eks-hybrid-downloads.s3.amazonaws.com/nodeadm/latest/linux-amd64/nodeadm"
      "https://s3.us-west-2.amazonaws.com/eks-hybrid-releases/latest/bin/linux/amd64/nodeadm"
    )
    for url in "$${nodeadm_urls[@]}"; do
      echo "Trying: $$url"
      if curl -fSL -o /tmp/nodeadm "$$url"; then
        sudo install -m 0755 /tmp/nodeadm /usr/local/bin/nodeadm
        break
      fi
      sleep 5
    done
    command -v nodeadm || { echo "nodeadm not installed"; exit 1; }
    nodeadm version || true

    # Instalar binarios k8s
    for i in {1..3}; do
      sudo nodeadm install ${var.kubernetes_version} --credential-provider ssm && break || sleep 15
    done

    # Config del nodo (usa activación SSM y datos del cluster)
    sudo mkdir -p /etc/nodeadm
    cat <<'NCFG' | sudo tee /etc/nodeadm/nodeConfig.yaml
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${var.eks_cluster_name}
        region: ${var.aws_region}
      hybrid:
        ssm:
          activationCode: ${aws_ssm_activation.hybrid.activation_code}
          activationId: ${aws_ssm_activation.hybrid.id}
    NCFG

    # Inicializar nodo
    for i in {1..3}; do
      sudo nodeadm init -c file:///etc/nodeadm/nodeConfig.yaml && break || sleep 10
    done

    # kubelet
    sudo systemctl enable --now kubelet || true

    # Diagnóstico
    systemctl is-active kubelet && echo "kubelet: ACTIVE" || echo "kubelet: FAILED"
    systemctl is-active containerd && echo "containerd: ACTIVE" || echo "containerd: FAILED"
    systemctl is-active amazon-ssm-agent && echo "ssm-agent: ACTIVE" || echo "ssm-agent: FAILED"

    echo "[$(date)] Bootstrap completed!"
  EOF

  hybrid_user_data_base64 = base64encode(local.hybrid_user_data)
}

############################################
# EC2 Híbrida (privada) — usa perfil de NODOS
############################################
resource "aws_instance" "hybrid_node" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.hybrid_instance_type
  subnet_id                   = module.hybrid_vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.hybrid_node.id]
  associate_public_ip_address = false
  key_name                    = var.hybrid_ssh_key_name
  iam_instance_profile        = aws_iam_instance_profile.hybrid_nodes.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  metadata_options {
    http_tokens = "required"
  }

  user_data_base64 = local.hybrid_user_data_base64

  tags = merge(var.tags, {
    Name         = "${var.eks_cluster_name}-hybrid-node",
    "eks-hybrid" = "true",
    Network      = "private",
    Subnet       = "private"
  })

  # Asegura que antes existan peering, rutas y endpoints SSM
  depends_on = [
    aws_vpc_peering_connection.cluster_hybrid,
    aws_route.hybrid_to_eks_private,
    aws_route.hybrid_to_eks_public,
    aws_vpc_endpoint.ssm_ifaces
  ]
}
