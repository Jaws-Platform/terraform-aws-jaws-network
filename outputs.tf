output "vpc_id" {
  description = "ID of the VPC, for security groups."
  value       = module.vpc.vpc_id
}

output "cidr_block" {
  description = "IPv4 CIDR of the VPC."
  value       = module.vpc.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, in the order of `availability_zones`."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, in the order of `availability_zones`. Empty without `private_subnet_cidrs`."
  value       = module.vpc.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the internet gateway."
  value       = module.vpc.internet_gateway_id
}

output "route_table_id" {
  description = "ID of the public route table."
  value       = module.vpc.route_table_id
}

output "private_route_table_id" {
  description = "ID of the private route table. Null without `private_subnet_cidrs`."
  value       = module.vpc.private_route_table_id
}

output "s3_endpoint_id" {
  description = "ID of the S3 gateway endpoint. Null unless `s3_gateway_endpoint.enabled`."
  value       = module.vpc.s3_endpoint_id
}

output "nat_instance_id" {
  description = "ID of the NAT instance. Null without `nat`."
  value       = one(module.nat[*].instance_id)
}

output "nat_public_ip" {
  description = "Public IPv4 address that traffic from the private subnets leaves from, for allow-lists at the destination. It changes when the NAT instance is replaced. Null without `nat`."
  value       = one(module.nat[*].public_ip)
}

output "nat_network_interface_id" {
  description = "ID of the NAT's network interface, the target of the private route table's default route. Null without `nat`."
  value       = one(module.nat[*].network_interface_id)
}

output "nat_security_group_id" {
  description = "ID of the NAT's security group. Null without `nat`."
  value       = one(module.nat[*].security_group_id)
}
