resource "aws_iam_instance_profile" "hybrid_nodes" {
  name = "eks-hybrid-nodes-instance-profile"
  role = aws_iam_role.hybrid_nodes.name
}
