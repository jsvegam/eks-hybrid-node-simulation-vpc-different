# eks-auth.tf (Opción A)
module "eks_aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.0"

  # No gestionar el ConfigMap aws-auth
  manage_aws_auth_configmap = false
}

output "aws_auth_status" {
  description = "Estado de la configuración de autenticación"
  value       = "aws-auth NO es gestionado por Terraform (usando Access Entries)"
}