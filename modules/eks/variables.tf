#############################
# modules/eks/variables.tf
#############################

variable "cluster_name" {
  description = "Nombre del clúster EKS"
  type        = string
}

variable "cluster_version" {
  description = "Versión de Kubernetes (p. ej. 1.28)"
  type        = string
}

variable "vpc_id" {
  description = "VPC donde se despliega el clúster"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets (normalmente privadas) para el clúster y node groups"
  type        = list(string)
}

# === FLAGS DE ENDPOINT (faltaban) ===
variable "endpoint_private_access" {
  description = "Acceso privado al endpoint del clúster"
  type        = bool
  default     = false
}

variable "endpoint_public_access" {
  description = "Acceso público al endpoint del clúster"
  type        = bool
  default     = true
}

# Node group
variable "desired_size" {
  description = "Tamaño deseado del node group"
  type        = number
}

variable "min_size" {
  description = "Tamaño mínimo del node group"
  type        = number
}

variable "max_size" {
  description = "Tamaño máximo del node group"
  type        = number
}

variable "instance_types" {
  description = "Tipos de instancia para el node group"
  type        = list(string)
}

variable "capacity_type" {
  description = "ON_DEMAND o SPOT"
  type        = string
  default     = "SPOT"
}

variable "disk_size" {
  description = "Tamaño en GB del volumen para cada nodo"
  type        = number
  default     = 20
}

# Acceso SSH opcional para el node group administrado
variable "key_name" {
  description = "Nombre del KeyPair para SSH (opcional)"
  type        = string
  default     = null
}

variable "remote_access_sg_ids" {
  description = "Security groups permitidos para SSH al node group (opcional)"
  type        = list(string)
  default     = []
}

# AMI type del node group (usa el por defecto si no quieres cambiarlo)
variable "ami_type" {
  description = "Tipo de AMI del node group (p. ej. AL2023_x86_64_STANDARD)"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

# Tags comunes
variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
