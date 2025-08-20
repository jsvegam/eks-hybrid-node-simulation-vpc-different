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

# Rol que usaremos para administrar el clúster vía CAM (Access Entries)
# ESTE ROL LO CREA terraform EN iam-console-admin.tf
variable "eks_console_admin_role_name" {
  description = "Nombre del rol IAM para operar el clúster"
  type        = string
  default     = "eks-console-admin"
}

# Etiquetas comunes
variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}

# EC2 híbrido
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
  default     = null
}

variable "hybrid_subnet_id" {
  description = "Subnet a usar para la EC2 híbrida (si no, se elige automáticamente)"
  type        = string
  default     = null
}

# Nombre del cluster y versión
variable "eks_cluster_name" {
  type        = string
  description = "Nombre del clúster EKS"
  default     = "my-eks-cluster"
}

variable "cluster_version" {
  type        = string
  description = "Versión de Kubernetes del clúster (por ejemplo 1.28)"
  default     = "1.28"
}


# Versión de Kubernetes que usará nodeadm en el nodo híbrido.
# Ponla igual que la versión del clúster.
variable "kubernetes_version" {
  description = "Kubernetes version for the hybrid node bootstrap (e.g., 1.28). Should match the EKS cluster version."
  type        = string
}

