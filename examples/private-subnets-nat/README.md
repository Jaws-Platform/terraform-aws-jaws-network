# Private subnets with a NAT instance

A VPC whose workloads sit in private subnets:

- two private `/20` subnets, one per availability zone, on one route table;
- a `t4g.nano` NAT instance in the first public subnet as their default
  route, for about $7 a month;
- an S3 gateway endpoint on the private route table, so same-region S3
  traffic never crosses the NAT.

The NAT image is resolved from a pinned name. Change the name deliberately to
move to a newer image: that replaces the instance, which changes its public
IP and interrupts egress for a couple of minutes.

```sh
terraform init
terraform plan
```

In your own configuration, replace the relative `source` with the registry
address:

```hcl
module "network" {
  source  = "jaws-platform/jaws-network/aws"
  version = "0.1.1" # x-release-please-version

  name                 = "acme-analytics"
  private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]

  s3_gateway_endpoint = { enabled = true }
  nat                 = { ami_id = data.aws_ami.nat.id }
}
```
