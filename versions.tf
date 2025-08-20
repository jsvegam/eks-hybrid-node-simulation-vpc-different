terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Sólo si realmente usas null_resource; si no, quítalo.
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    # <- NO incluyas hashicorp/template
  }
}
