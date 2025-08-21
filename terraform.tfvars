aws_region          = "us-east-1"
aws_profile         = "eks-operator"
eks_cluster_name    = "my-eks-cluster"
cluster_version     = "1.28"
kubernetes_version  = "1.28"
hybrid_ssh_key_name = "eks-hybrid-debug"



# Opcional (ajusta o deja por defecto)
eks_console_admin_role_name = "eks-console-admin"
hybrid_instance_type        = "t3.small"
hybrid_registration_limit   = 1
tags = {
  Environment = "production"
}

