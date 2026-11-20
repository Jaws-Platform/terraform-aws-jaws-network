provider "aws" {
  region = "us-east-1"

  # The modules take no tag map. Every resource inherits these, and each
  # module adds `Component` and `Name`.
  default_tags {
    tags = {
      Project     = "analytics"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  # Two /20s in the upper half of the VPC, clear of the public /24s that are
  # carved from its start.
  vpc_cidr             = "10.0.0.0/16"
  private_subnet_cidrs = [cidrsubnet(local.vpc_cidr, 4, 8), cidrsubnet(local.vpc_cidr, 4, 9)]
}

# The NAT image is resolved from a pinned name, so a new Amazon Linux release
# does not replace the instance. Deprecated images are included so that the
# pin keeps resolving.
data "aws_ami" "nat" {
  owners             = ["amazon"]
  include_deprecated = true
  most_recent        = false

  filter {
    name   = "name"
    values = ["al2023-ami-2023.6.20250115.0-kernel-6.1-arm64"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# Private subnets whose default route is a NAT instance in the first public
# subnet, with same-region S3 traffic kept off the NAT by a gateway endpoint.
module "network" {
  source = "../../"

  name                 = "acme-analytics"
  cidr_block           = local.vpc_cidr
  availability_zones   = ["us-east-1a", "us-east-1b"]
  private_subnet_cidrs = local.private_subnet_cidrs

  s3_gateway_endpoint = { enabled = true }
  nat                 = { ami_id = data.aws_ami.nat.id }
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, for the workloads."
  value       = module.network.private_subnet_ids
}

output "nat_public_ip" {
  description = "The address private traffic leaves from, for allow-lists."
  value       = module.network.nat_public_ip
}
