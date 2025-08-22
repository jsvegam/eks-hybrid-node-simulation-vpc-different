############################################
# SG para Interface Endpoints de SSM
############################################
resource "aws_security_group" "ssm_endpoints" {
  name        = "${var.eks_cluster_name}-ssm-endpoints-sg"
  description = "Security group for SSM interface endpoints"
  vpc_id      = module.hybrid_vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.eks_cluster_name}-ssm-endpoints-sg"
  })
}

# Permite HTTPS desde toda la VPC híbrida hacia los endpoints
resource "aws_security_group_rule" "ssm_endpoints_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [module.hybrid_vpc.vpc_cidr_block]
  security_group_id = aws_security_group.ssm_endpoints.id
  description       = "Allow HTTPS from hybrid VPC to SSM interface endpoints"
}

############################################
# Interface Endpoints requeridos por SSM
############################################
locals {
  ssm_services = toset([
    "com.amazonaws.${var.aws_region}.ssm",
    "com.amazonaws.${var.aws_region}.ssmmessages",
    "com.amazonaws.${var.aws_region}.ec2messages",
  ])
}

resource "aws_vpc_endpoint" "ssm_ifaces" {
  for_each            = local.ssm_services
  vpc_id              = module.hybrid_vpc.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.hybrid_vpc.private_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.eks_cluster_name}-${replace(each.value, ".", "-")}"
  })
}

