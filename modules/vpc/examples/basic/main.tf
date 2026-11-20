locals {
  # Modules take no tag map. Every resource inherits these through the
  # provider's default_tags, and each module adds `Component` (and `Name`).
  tags = {
    Organization = "acme"
    Project      = "chess-bot"
    Environment  = "prod"
    Repository   = "acme/chess-bot"
    ManagedBy    = "terraform"
    Owner        = "platform-team"
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = local.tags
  }
}

module "network" {
  source = "../../"

  name = "acme-chess-bot"
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}
