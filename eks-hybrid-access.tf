# Rol que usarán los "hybrid nodes" registrados por SSM
resource "aws_iam_role" "hybrid_nodes" {
  provider = aws.virginia
  name     = "eks-hybrid-nodes-role"

  assume_role_policy = data.aws_iam_policy_document.hybrid_nodes_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "hybrid_nodes_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "hybrid_nodes_ssm_core" {
  provider   = aws.virginia
  role       = aws_iam_role.hybrid_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Activation SSM para registrar el/los híbridos
resource "aws_ssm_activation" "hybrid" {
  provider           = aws.virginia
  name               = "eks-hybrid-activation"
  description        = "Hybrid activation for EKS hybrid node(s)"
  iam_role           = aws_iam_role.hybrid_nodes.name
  registration_limit = var.hybrid_registration_limit
  tags               = var.tags
}

# Access Entry para que el rol de híbridos se registre como nodos
resource "aws_eks_access_entry" "hybrid_nodes" {
  provider      = aws.virginia
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.hybrid_nodes.arn
  type          = "HYBRID_LINUX"

  depends_on = [module.eks, aws_iam_role.hybrid_nodes]
}
