# remote-network.tf
# Configura remoteNetworkConfig para EKS Hybrid Nodes (idempotente).
# Requiere AWS CLI v2.17+ (tiene remoteNodeNetworks/remotePodNetworks).

resource "null_resource" "enable_remote_network_config" {
  # Re-evaluar si cambia el nombre del cluster, región o el CIDR híbrido
  triggers = {
    cluster_name = module.eks.cluster_name
    region       = var.aws_region
    hybrid_cidr  = module.hybrid_vpc.vpc_cidr_block
    aws_profile  = var.aws_profile
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      echo "[INFO] Checking remoteNetworkConfig for cluster ${module.eks.cluster_name} in ${var.aws_region}"

      CURRENT=$(aws eks describe-cluster \
        --region "${var.aws_region}" \
        --name   "${module.eks.cluster_name}" \
        --profile "${var.aws_profile}" \
        --query 'cluster.remoteNetworkConfig.remoteNodeNetworks[].cidrs[]' \
        --output text 2>/dev/null || echo "")

      if [[ "$CURRENT" == *"${module.hybrid_vpc.vpc_cidr_block}"* ]]; then
        echo "[INFO] remoteNetworkConfig ya incluye ${module.hybrid_vpc.vpc_cidr_block}"
        exit 0
      fi

      echo "[INFO] Aplicando remoteNodeNetworks con CIDR ${module.hybrid_vpc.vpc_cidr_block}"
      set +e
      aws eks update-cluster-config \
        --region "${var.aws_region}" \
        --name   "${module.eks.cluster_name}" \
        --profile "${var.aws_profile}" \
        --remote-network-config "{\"remoteNodeNetworks\":[{\"cidrs\":[\"${module.hybrid_vpc.vpc_cidr_block}\"]}]}"
      RC=$?
      set -e
      if [[ $RC -ne 0 ]]; then
        echo "[WARN] update-cluster-config falló (exit=$RC). ¿CLI < v2.17? No fallo el apply, pero deberás actualizar el AWS CLI y reintentar."
        exit 0
      fi

      echo "[INFO] Solicitud enviada."
    EOT
  }

  # Asegura que existen el cluster y la VPC híbrida para poder obtener el CIDR
  depends_on = [
    module.eks,
    module.hybrid_vpc
  ]
}
