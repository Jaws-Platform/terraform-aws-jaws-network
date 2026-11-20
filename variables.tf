variable "name" {
  description = "Name of the VPC in kebab-case, for example `acme-analytics`. The subnets, gateway and route tables are named after it, and the NAT instance is `<name>-nat`."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.name)) && length(var.name) <= 60
    error_message = "name must be kebab-case (lowercase letters, digits and single hyphens) and at most 60 characters, so that `<name>-nat` fits the NAT's 64-character limit."
  }
}

variable "cidr_block" {
  description = "IPv4 CIDR of the VPC, between /16 and /24. Each public subnet is a /24 carved from its start."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones that get one public subnet each, in order, and one private subnet each when `private_subnet_cidrs` is set. Append zones rather than reordering: subnets are numbered by position."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnet_cidrs" {
  description = "IPv4 CIDRs of the private subnets, one per entry of `availability_zones` and in the same order, or empty for none. Each must sit inside `cidr_block` and clear of the public /24s at its start; the upper half of the VPC is a safe place."
  type        = list(string)
  default     = []
}

variable "s3_gateway_endpoint" {
  description = "Optional S3 gateway endpoint on the private route table, which keeps same-region S3 traffic off the NAT. It needs `private_subnet_cidrs`. `policy` is an endpoint policy JSON document, passed through unchanged; omit it for the AWS default (full access)."
  type = object({
    enabled = bool
    policy  = optional(string)
  })
  default = { enabled = false }
}

variable "nat" {
  description = "Optional NAT instance that gives the private subnets a default route to the internet: `ami_id` is an Amazon Linux 2023 arm64 image (resolve it from a pinned name, so a new release does not replace the NAT) and `instance_type` an arm64 type from the `t4g`, `c7g`, `c8g` or `m7g` families. It needs `private_subnet_cidrs`. Null creates no NAT, and the private subnets then have no route out."
  type = object({
    ami_id        = string
    instance_type = optional(string, "t4g.nano")
  })
  default = null

  validation {
    condition     = var.nat == null || length(var.private_subnet_cidrs) > 0
    error_message = "nat requires private subnets, because it is their default route: set private_subnet_cidrs, or set nat to null."
  }
}
