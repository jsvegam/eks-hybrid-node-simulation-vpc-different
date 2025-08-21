# AMI for Amazon Linux 2023
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Security group for the Hybrid node
resource "aws_security_group" "hybrid_node" {
  name        = "${var.eks_cluster_name}-hybrid-node-sg"
  description = "Security group for Hybrid node in private subnet"
  vpc_id      = module.hybrid_vpc.vpc_id

  # Allow SSH from within the VPC only (opcional)
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [module.hybrid_vpc.vpc_cidr_block]
  }

  # Allow node to receive traffic from cluster VPC
  ingress {
    description = "EKS cluster communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # PERMITE TODO EL TRÁFICO SALIENTE (NAT Gateway lo maneja)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    "Name"       = "${var.eks_cluster_name}-hybrid-node-sg"
    "eks-hybrid" = "true"
    "Tier"       = "private"
  })
}

# User data to bootstrap SSM + nodeadm 
locals {
  aws_region  = var.aws_region
  k8s_version = var.kubernetes_version

  nodeadm_config = <<-YAML
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${var.cluster_name}
        region: ${var.aws_region}
      hybrid:
        ssm:
          activationCode: ${aws_ssm_activation.hybrid.activation_code}
          activationId: ${aws_ssm_activation.hybrid.id}
  YAML

  hybrid_user_data_script = <<-EOF
#!/usr/bin/env bash
set -euxo pipefail

# Configura logging detallado
exec > >(tee /var/log/hybrid-bootstrap.log) 2>&1
echo "[$(date)] Starting EKS Hybrid Node bootstrap"

# Configurar DNS para evitar problemas de resolución
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf

# 0) Paquetes base con reintentos
for i in {1..5}; do
  sudo dnf -y update && break || sleep 30
done

for i in {1..5}; do
  sudo dnf -y install amazon-ssm-agent tar curl && break || sleep 30
done

# 1) SSM Agent
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

# 2) Registro HYBRID con reintentos
for i in {1..3}; do
  sudo /usr/bin/amazon-ssm-agent -register \
    -code '${aws_ssm_activation.hybrid.activation_code}' \
    -id '${aws_ssm_activation.hybrid.id}' \
    -region '${var.aws_region}' -y && break || sleep 10
done

sudo systemctl restart amazon-ssm-agent

# 3) nodeadm con múltiples URLs de respaldo
nodeadm_urls=(
  "https://hybrid-assets.regionless.eks.amazonaws.com/releases/latest/bin/linux/amd64/nodeadm"
  "https://eks-hybrid-downloads.s3.amazonaws.com/nodeadm/latest/linux-amd64/nodeadm" 
  "https://s3.us-west-2.amazonaws.com/eks-hybrid-releases/latest/bin/linux/amd64/nodeadm"
)

for url in "$${nodeadm_urls[@]}"; do
  echo "Trying: $$url"
  if curl -fSL -o /tmp/nodeadm "$$url"; then
    sudo mv /tmp/nodeadm /usr/local/bin/nodeadm
    sudo chmod +x /usr/local/bin/nodeadm
    echo "nodeadm downloaded successfully from $$url"
    break
  fi
  echo "Failed to download from $$url"
  sleep 5
done

# Verificar que nodeadm se instaló
if ! command -v nodeadm >/dev/null 2>&1; then
  echo "ERROR: nodeadm installation failed!"
  exit 1
fi

echo "nodeadm version: $(nodeadm version)"

# 4) Instalar componentes de Kubernetes
for i in {1..3}; do
  sudo nodeadm install ${var.kubernetes_version} --credential-provider ssm && break || sleep 15
done

# 5) Crear configuración del nodo
sudo mkdir -p /etc/nodeadm
sudo cat > /etc/nodeadm/nodeConfig.yaml << NCFG
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${var.cluster_name}
    region: ${var.aws_region}
  hybrid:
    ssm:
      activationCode: ${aws_ssm_activation.hybrid.activation_code}
      activationId: ${aws_ssm_activation.hybrid.id}
NCFG

# 6) Inicializar el nodo
for i in {1..3}; do
  sudo nodeadm init -c file:///etc/nodeadm/nodeConfig.yaml && break || sleep 10
done

# 7) Habilitar e iniciar kubelet
sudo systemctl enable kubelet
sudo systemctl start kubelet

# 8) Verificación final
echo "Verifying services..."
sudo systemctl is-active kubelet && echo "kubelet: ACTIVE" || echo "kubelet: FAILED"
sudo systemctl is-active containerd && echo "containerd: ACTIVE" || echo "containerd: FAILED"
sudo systemctl is-active amazon-ssm-agent && echo "ssm-agent: ACTIVE" || echo "ssm-agent: FAILED"

echo "[$(date)] Bootstrap completed successfully!"
EOF

  hybrid_user_data_base64 = base64encode(local.hybrid_user_data_script)
}

resource "aws_instance" "hybrid_node" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.hybrid_instance_type
  subnet_id                   = module.hybrid_vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.hybrid_node.id]
  associate_public_ip_address = false
  key_name                    = var.hybrid_ssh_key_name

  # Disco raíz más grande
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data_base64 = local.hybrid_user_data_base64

  tags = merge(var.tags, {
    "Name"       = "${var.eks_cluster_name}-hybrid-node",
    "eks-hybrid" = "true",
    "Network"    = "private",
    "Subnet"     = "private"
  })

  depends_on = [
    null_resource.enable_remote_network_config,
    module.hybrid_vpc,
    aws_vpc_peering_connection.cluster_hybrid
    # SE ELIMINÓ: aws_route_table_association.private (ya no existe)
  ]
}