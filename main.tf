# Root module: a VPC, and optionally a NAT instance for its private subnets.
#
#   public subnets   one /24 per availability zone, routed to the internet gateway
#   private subnets  optional, one per zone, on one route table
#   NAT instance     optional, in the first public subnet: the private route
#                    table's default route
#   S3 endpoint      optional gateway endpoint on the private route table
#
# It only wires the two submodules together. Each can be used on its own, and
# both keep their own input validation.

module "vpc" {
  source = "./modules/vpc"

  name                 = var.name
  cidr_block           = var.cidr_block
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  s3_gateway_endpoint  = var.s3_gateway_endpoint
}

module "nat" {
  source = "./modules/nat-instance"
  count  = var.nat == null ? 0 : 1

  name                    = "${var.name}-nat"
  subnet_id               = module.vpc.public_subnet_ids[0]
  private_route_table_ids = [module.vpc.private_route_table_id]
  source_cidrs            = var.private_subnet_cidrs
  ami_id                  = var.nat.ami_id
  instance_type           = var.nat.instance_type
}
