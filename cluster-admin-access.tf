# Crea Access Entry CAM para el rol "eks-console-admin" que acabamos de crear
############################################
# cluster-admin-access.tf
############################################

# Crea la Access Entry tipo STANDARD para el rol de operación del cluster
resource "aws_eks_access_entry" "admin" {
  provider      = aws.virginia
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.eks_console_admin.arn
  type          = "STANDARD"

  depends_on = [module.eks] # espera al cluster (y a su access_config)
}

# Asocia la policy de admin de EKS (CAM)
resource "aws_eks_access_policy_association" "admin" {
  provider      = aws.virginia
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope { type = "cluster" }

  depends_on = [aws_eks_access_entry.admin]
}
