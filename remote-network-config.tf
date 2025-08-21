# Attempt to enable remoteNetworkConfig on the cluster (required for Hybrid Nodes).
# This uses AWS CLI because provider support may lag.

resource "null_resource" "enable_remote_network_config" {
  triggers = {
    cluster_name = var.cluster_name
    region       = var.aws_region
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command = <<-EOC
      set -euo pipefail
      echo "[INFO] Checking remoteNetworkConfig for cluster ${var.cluster_name} in ${var.aws_region}"
      CURRENT=$(aws eks describe-cluster --region "${var.aws_region}" --name "${var.cluster_name}" --query 'cluster.remoteNetworkConfig' --output json || echo null)
      if [[ "$CURRENT" != "null" && "$CURRENT" != "None" && "$CURRENT" != "" ]]; then
        echo "[INFO] remoteNetworkConfig already present: $CURRENT"
        exit 0
      fi

      echo "[INFO] Trying to enable remoteNetworkConfig via AWS CLI..."
      # Try syntax variant A (most recent)
      set +e
      aws eks update-cluster-config \
        --region "${var.aws_region}" \
        --name "${var.cluster_name}" \
        --remote-network-config '{"remoteNodeNetwork":{}}'
      RC=$?
      set -e
      if [[ $RC -ne 0 ]]; then
        echo "[WARN] update-cluster-config failed (exit=$RC). This may indicate your AWS CLI is outdated."
        echo "[HINT] Upgrade to AWS CLI v2.17+ and re-run: aws eks update-cluster-config --region ${var.aws_region} --name ${var.cluster_name} --remote-network-config '{\"remoteNodeNetwork\":{}}'"
        # Do not fail the apply; nodeadm will still error with a clear message if this isn't enabled.
        exit 0
      fi
      echo "[INFO] Requested remoteNetworkConfig enablement."
    EOC
  }

  depends_on = [module.eks]
}