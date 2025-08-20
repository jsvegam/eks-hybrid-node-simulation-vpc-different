
# Provider por defecto (usa tu var.region)
provider "aws" {
  region = var.region
}

# Alias (opcional) si de verdad lo necesitas en algún module/resource
provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}
