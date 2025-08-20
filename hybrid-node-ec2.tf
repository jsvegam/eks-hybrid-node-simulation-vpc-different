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
  description = "Security group for Hybrid node EC2"
  vpc_id      = module.hybrid_vpc.vpc_id

  # Allow SSH (optional)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow node to receive traffic from cluster VPC (for debugging / NodePort if needed)
  ingress {
    description = "Cluster VPC <> Hybrid"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    "Name"       = "${var.eks_cluster_name}-hybrid-node-sg"
    "eks-hybrid" = "true"
  })
}

# User data to bootstrap SSM + nodeadm only after remoteNetworkConfig is in place.
locals {
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
}

data "template_cloudinit_config" "hybrid_user_data" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOT
      #!/bin/bash
      set -euxo pipefail

      echo "[BOOTSTRAP] Starting hybrid node bootstrap"

      # Ensure SSM agent is installed and running
      systemctl enable --now amazon-ssm-agent || true

      # Write nodeadm config file
      install -d /etc/nodeadm
      cat > /etc/nodeadm/nodeConfig.yaml <<'CFG'
      ${local.nodeadm_config}
      CFG

      # Install or update nodeadm (latest)
      curl -fsSL https://raw.githubusercontent.com/aws/eks-hybrid/main/install-nodeadm.sh | bash

      # Install containerd (if not present)
      if ! command -v containerd >/dev/null 2>&1; then
        dnf install -y containerd
        systemctl enable --now containerd
      else
        systemctl enable --now containerd || true
      fi

      # Register SSM if not already registered
      if ! grep -q "managedInstanceID" /var/lib/amazon/ssm/registration || ! systemctl is-active --quiet amazon-ssm-agent; then
        echo "[BOOTSTRAP] Registering with SSM Managed Instance..."
        /usr/bin/amazon-ssm-agent -register -code "${aws_ssm_activation.hybrid.activation_code}" -id "${aws_ssm_activation.hybrid.id}" -region "${var.aws_region}" || true
        systemctl restart amazon-ssm-agent
      fi

      # Try to init the node (this will fail if remoteNetworkConfig isn't enabled yet)
      echo "[BOOTSTRAP] Running nodeadm init..."
      nodeadm init --config-source file:///etc/nodeadm/nodeConfig.yaml || true

      # If init succeeded, kubelet will be managed by nodeadm.
      # If it failed, you can re-run manually after enabling remoteNetworkConfig:
      #   sudo nodeadm init --config-source file:///etc/nodeadm/nodeConfig.yaml
      echo "[BOOTSTRAP] Done"
    EOT
  }
}

resource "aws_instance" "hybrid_node" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.hybrid_instance_type
  subnet_id                   = module.hybrid_vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.hybrid_node.id]
  associate_public_ip_address = true
  key_name                    = var.hybrid_key_name

  user_data_base64 = data.template_cloudinit_config.hybrid_user_data.rendered

  tags = merge(var.tags, {
    "Name"       = "${var.eks_cluster_name}-hybrid-node",
    "eks-hybrid" = "true"
  })

  depends_on = [
    null_resource.enable_remote_network_config,
    module.hybrid_vpc,
    aws_vpc_peering_connection.cluster_hybrid
  ]
}