#########################################
# hybrid-ec2-iam.tf — IAM para nodo híbrido (sin EC2 Instance Connect)
# - Crea un rol para EC2.
# - Adjunta SOLO AmazonSSMManagedInstanceCore.
# - Si usas HYBRID Activation, NO referencies este instance profile
#   en aws_instance.hybrid_node (para que registre como HYBRID "mi-...").
#########################################

resource "aws_iam_role" "hybrid_ec2" {
  provider = aws.virginia
  name     = "eks-hybrid-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# Solo SSM core para que funcione el agente SSM (no agregues EC2InstanceConnect)
resource "aws_iam_role_policy_attachment" "hybrid_ec2_ssm" {
  provider   = aws.virginia
  role       = aws_iam_role.hybrid_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile (OPCIONAL). Úsalo solo si quieres administrar la EC2 como "EC2 managed"
# En modo HYBRID (con Activation Code/ID) **NO** lo adjuntes a aws_instance.hybrid_node.
resource "aws_iam_instance_profile" "hybrid_ec2" {
  provider = aws.virginia
  name     = "eks-hybrid-ec2-instance-profile"
  role     = aws_iam_role.hybrid_ec2.name
}

# (opcionales) salidas prácticas
output "hybrid_ec2_role_arn" {
  value = aws_iam_role.hybrid_ec2.arn
}

output "hybrid_ec2_instance_profile_name" {
  value = aws_iam_instance_profile.hybrid_ec2.name
}
