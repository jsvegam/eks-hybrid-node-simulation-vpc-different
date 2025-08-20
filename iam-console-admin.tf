# Rol que tú asumirás desde tu usuario NO-root
data "aws_caller_identity" "this" {}

resource "aws_iam_role" "eks_console_admin" {
  name = var.eks_console_admin_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:root" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# Para laboratorio: permisos amplios; en producción, usa políticas mínimas.
resource "aws_iam_role_policy_attachment" "eks_console_admin_admin" {
  role       = aws_iam_role.eks_console_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "eks_console_admin_role_arn" {
  value = aws_iam_role.eks_console_admin.arn
}
