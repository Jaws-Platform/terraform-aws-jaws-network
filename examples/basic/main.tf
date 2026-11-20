provider "aws" {
  region = "us-east-1"

  # The modules take no tag map. Every resource inherits these, and each
  # module adds `Component` and `Name`.
  default_tags {
    tags = {
      Project     = "chess-bot"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

# One public subnet in each of two zones, an internet gateway and a route
# table. No private subnets and no NAT: an instance here gets a public
# address, and a security group without ingress rules keeps it unreachable.
module "network" {
  source = "../../"

  name = "acme-chess-bot"
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.network.public_subnet_ids
}
