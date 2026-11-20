locals {
  # Modules take no tag map. Every resource inherits these through the
  # provider's default_tags, and each module adds `Component` (and `Name`).
  tags = {
    Organization = "acme"
    Project      = "analytics"
    Environment  = "prod"
    Repository   = "example/infra"
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
  source = "../../../vpc"

  name                 = "team-a-analytics"
  availability_zones   = ["us-east-1a"]
  private_subnet_cidrs = ["10.0.2.0/24"]
}

# Pinned AL2023 arm64 image, so a new release does not replace the NAT.
data "aws_ami" "al2023_arm64" {
  owners      = ["amazon"]
  most_recent = false
  filter {
    name   = "name"
    values = ["al2023-ami-2023.6.20250115.0-kernel-6.1-arm64"]
  }
}

module "nat" {
  source = "../../"

  name                    = "team-a-analytics-nat"
  subnet_id               = module.network.public_subnet_ids[0]
  private_route_table_ids = [module.network.private_route_table_id]
  source_cidrs            = ["10.0.2.0/24"]
  ami_id                  = data.aws_ami.al2023_arm64.id
}

output "nat_public_ip" {
  value = module.nat.public_ip
}
