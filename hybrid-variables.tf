// hybrid-variables.tf (corregido)
variable "hybrid_vpc_cidr" {
  description = "CIDR for the Hybrid (on-prem emulation) VPC"
  type        = string
  default     = "172.16.0.0/16"
}

variable "hybrid_public_subnets" {
  description = "Public subnets for Hybrid VPC (one per AZ used)"
  type        = list(string)
  default     = ["172.16.1.0/24", "172.16.2.0/24"]
}

variable "hybrid_key_name" {
  description = "Optional EC2 KeyPair for SSH to Hybrid node"
  type        = string
  default     = null
}
