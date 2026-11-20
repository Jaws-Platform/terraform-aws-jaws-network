# Basic: a VPC with public subnets

One public subnet in each of two availability zones, an internet gateway and
one route table. No private subnets, no NAT and no endpoints, so nothing here
has a standing cost.

An instance launched into it gets a public IPv4 address. Give it a security
group without ingress rules and it can reach the internet without being
reachable from it.

```sh
terraform init
terraform plan
```

In your own configuration, replace the relative `source` with the registry
address:

```hcl
module "network" {
  source  = "Jaws-Platform/jaws-network/aws"
  version = "0.1.0" # x-release-please-version

  name = "acme-chess-bot"
}
```
