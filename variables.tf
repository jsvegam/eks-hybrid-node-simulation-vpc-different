variable "aws_region" {
  description = "Región AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil de credenciales local (aws configure --profile ...)"
  type        = string
  default     = "eks-operator"
}

variable "eks_console_admin_role_name" {
  description = "Nombre del rol IAM para operar el clúster"
  type        = string
  default     = "eks-console-admin"
}

variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}

variable "hybrid_registration_limit" {
  description = "Máximo de hosts que pueden registrarse con la activación SSM"
  type        = number
  default     = 1
}

variable "hybrid_instance_type" {
  description = "Tipo de instancia EC2 para el nodo híbrido"
  type        = string
  default     = "t3.small"
}

variable "hybrid_ssh_key_name" {
  description = "KeyPair SSH (opcional)"
  type        = string
  default     = "eks-hybrid-debug"
}

variable "hybrid_subnet_id" {
  description = "Subnet a usar para la EC2 híbrida (si no, se elige automáticamente)"
  type        = string
  default     = null
}

variable "eks_cluster_name" {
  type        = string
  description = "Nombre del clúster EKS"
  default     = "my-eks-cluster"
}

variable "cluster_version" {
  type        = string
  description = "Versión de Kubernetes del clúster (por ejemplo 1.28)"
  default     = "1.29"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the hybrid node bootstrap (e.g., 1.28). Should match the EKS cluster version."
  type        = string
  default     = "1.29"
}

# Variables adicionales necesarias para los errores
variable "cluster_name" {
  description = "Name of the cluster (same as eks_cluster_name)"
  type        = string
  default     = "my-eks-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the main VPC"
  type        = string
  default     = "10.0.0.0/16"
}


