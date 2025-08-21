# eks-auth.tf
# Configuración de acceso IAM al cluster EKS

# Usa el data source existente de data.tf
module "eks_aws_auth" {
  source = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.0"

  manage_aws_auth_configmap = true

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/eks-operator"
      username = "eks-operator"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-console-admin"
      username = "eks-console-admin"
      groups   = ["system:masters"]
    },
    {
      rolearn  = module.eks.cluster_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    }
  ]

  depends_on = [module.eks]
}

output "aws_auth_status" {
  description = "Estado de la configuración de autenticación"
  value       = "AWS Auth ConfigMap configurado para usuario eks-operator"
}