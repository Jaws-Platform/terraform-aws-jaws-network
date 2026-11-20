# terraform-aws-jaws-network

[![Terraform Registry](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fregistry.terraform.io%2Fv1%2Fmodules%2FJaws-Platform%2Fjaws-network%2Faws&query=%24.version&prefix=v&label=registry&logo=terraform&color=7B42BC)](https://registry.terraform.io/modules/Jaws-Platform/jaws-network/aws/latest)
[![GitHub release](https://img.shields.io/github/v/release/Jaws-Platform/terraform-aws-jaws-network?label=release)](https://github.com/Jaws-Platform/terraform-aws-jaws-network/releases/latest)
[![CI](https://github.com/Jaws-Platform/terraform-aws-jaws-network/actions/workflows/ci.yml/badge.svg?event=pull_request)](https://github.com/Jaws-Platform/terraform-aws-jaws-network/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Jaws-Platform/terraform-aws-jaws-network/blob/main/LICENSE)

A small, cheap AWS network for workloads that reach out to the internet and
are never reached from it: a VPC with public subnets, optional private
subnets, and a **NAT instance** that costs about $7 a month where a NAT
gateway costs about $33 plus data processing.

It is one of the [Jaws](https://github.com/jwallace145/jaws) module families,
and has no dependency on Jaws: everything is a plain input.

## What it creates

```text
                              internet
                                 │
                        ┌────────┴─────────┐
                        │ internet gateway │
                        └────────┬─────────┘
 ┌─ VPC (cidr_block) ────────────┼──────────────────────────────────┐
 │                               │                                  │
 │   public route table:  0.0.0.0/0 ──► internet gateway            │
 │  ┌────────────────────────┐    ┌────────────────────────┐        │
 │  │ public subnet, zone a  │    │ public subnet, zone b  │   ...  │
 │  │ /24, public IPs        │    │ /24, public IPs        │        │
 │  │   ┌──────────────┐     │    │                        │        │
 │  │   │ NAT instance │     │    │                        │        │
 │  │   └──────▲───────┘     │    │                        │        │
 │  └──────────┼─────────────┘    └────────────────────────┘        │
 │             │                                                    │
 │   private route table: 0.0.0.0/0 ──► NAT network interface       │
 │                        S3 prefix list ──► S3 gateway endpoint    │
 │  ┌────────────────────────┐    ┌────────────────────────┐        │
 │  │ private subnet, zone a │    │ private subnet, zone b │   ...  │
 │  └────────────────────────┘    └────────────────────────┘        │
 └──────────────────────────────────────────────────────────────────┘
```

Only the VPC, the public subnets, the internet gateway and the public route
table are created by default. The private subnets, the NAT instance and the
S3 gateway endpoint are each opt-in.

## Modules

| Module | Creates |
|---|---|
| [root](https://registry.terraform.io/modules/Jaws-Platform/jaws-network/aws/latest) | The whole picture above in one call: `vpc`, plus `nat-instance` when `nat` is set. |
| [`vpc`](https://registry.terraform.io/modules/Jaws-Platform/jaws-network/aws/latest/submodules/vpc) | The VPC, one public `/24` per availability zone, the internet gateway and the public route table; optionally private subnets on one route table and an S3 gateway endpoint. No NAT. |
| [`nat-instance`](https://registry.terraform.io/modules/Jaws-Platform/jaws-network/aws/latest/submodules/nat-instance) | A default route for private route tables through one small arm64 instance: IP forwarding and `iptables` masquerading, IMDSv2, an encrypted root volume and a security group that admits only the private CIDRs. Works with any VPC. |

## Usage

A VPC with public subnets only. An instance in it gets a public address, and
a security group without ingress rules keeps it unreachable:

```hcl
module "network" {
  source  = "Jaws-Platform/jaws-network/aws"
  version = "0.1.2" # x-release-please-version

  name = "acme-chess-bot"
}
```

Private subnets with egress through a NAT instance, and S3 traffic kept off
it by a gateway endpoint:

```hcl
# Resolve the NAT image from a pinned name, so a new Amazon Linux release
# does not replace the instance.
data "aws_ami" "nat" {
  owners      = ["amazon"]
  most_recent = false

  filter {
    name   = "name"
    values = ["al2023-ami-2023.6.20250115.0-kernel-6.1-arm64"]
  }
}

module "network" {
  source  = "Jaws-Platform/jaws-network/aws"
  version = "0.1.2" # x-release-please-version

  name                 = "acme-analytics"
  cidr_block           = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]

  s3_gateway_endpoint = { enabled = true }
  nat                 = { ami_id = data.aws_ami.nat.id }
}
```

Each submodule can also be used on its own, for example `nat-instance` behind
a VPC you already have:

```hcl
module "nat" {
  source  = "Jaws-Platform/jaws-network/aws//modules/nat-instance"
  version = "0.1.2" # x-release-please-version

  name                    = "acme-analytics-nat"
  subnet_id               = "subnet-0123456789abcdef0" # a public subnet
  private_route_table_ids = ["rtb-0123456789abcdef0"]
  source_cidrs            = ["10.0.128.0/20", "10.0.144.0/20"]
  ami_id                  = data.aws_ami.nat.id
}
```

## Examples

- [`basic`](https://github.com/Jaws-Platform/terraform-aws-jaws-network/tree/main/examples/basic):
  a VPC with public subnets only.
- [`private-subnets-nat`](https://github.com/Jaws-Platform/terraform-aws-jaws-network/tree/main/examples/private-subnets-nat):
  private subnets, a NAT instance and an S3 gateway endpoint.

## Cost

| | Per month, us-east-1 |
|---|---|
| VPC, subnets, route tables, internet gateway, S3 gateway endpoint | free |
| NAT instance: `t4g.nano` on demand, its public IPv4 address and an 8 GB gp3 volume | about $7 |
| For comparison, a NAT gateway | about $33, plus $0.045 per GB processed |

Data transfer out to the internet is billed as usual either way.

## What to know before using it

- **`us-east-1` only.** Availability zones are validated as `us-east-1[a-f]`
  and the S3 endpoint is the `us-east-1` service.
- **The NAT instance is a single point of failure**: one instance in one
  zone, with no failover. If its host fails, EC2 restarts the same instance
  and the routes are unaffected; a failure of the whole zone takes egress down
  until it returns. Use a NAT gateway where egress must survive that.
- **Replacing the NAT instance changes its public IP** and black-holes egress
  for a couple of minutes while the new one boots. A new `ami_id`,
  `instance_type` or set of private CIDRs replaces it.
- **No IPv6, no flow logs, no alarms.**
- **Providers are never configured here.** The caller configures `aws`.
- **Tags.** Every resource gets `Name` and `Component` from the module. Every
  other tag comes from the caller's provider `default_tags`; the modules take
  no tag map.

The submodule READMEs have the details: how the NAT is set up, how routes
follow a replacement, and how private subnet CIDRs are validated.

## Development

See [CONTRIBUTING.md](https://github.com/Jaws-Platform/terraform-aws-jaws-network/blob/main/CONTRIBUTING.md)
for local setup, the commit and pull request rules, CI, and how releases work.
`scripts/check.sh` runs everything CI runs, with no AWS credentials.

## Root module reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11 |
| aws | ~> 6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| nat | ./modules/nat-instance | n/a |
| vpc | ./modules/vpc | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name of the VPC in kebab-case, for example `acme-analytics`. The subnets, gateway and route tables are named after it, and the NAT instance is `<name>-nat`. | `string` | n/a | yes |
| availability\_zones | Availability zones that get one public subnet each, in order, and one private subnet each when `private_subnet_cidrs` is set. Append zones rather than reordering: subnets are numbered by position. | `list(string)` | <pre>[<br/>  "us-east-1a",<br/>  "us-east-1b"<br/>]</pre> | no |
| cidr\_block | IPv4 CIDR of the VPC, between /16 and /24. Each public subnet is a /24 carved from its start. | `string` | `"10.0.0.0/16"` | no |
| nat | Optional NAT instance that gives the private subnets a default route to the internet: `ami_id` is an Amazon Linux 2023 arm64 image (resolve it from a pinned name, so a new release does not replace the NAT) and `instance_type` an arm64 type from the `t4g`, `c7g`, `c8g` or `m7g` families. It needs `private_subnet_cidrs`. Null creates no NAT, and the private subnets then have no route out. | <pre>object({<br/>    ami_id        = string<br/>    instance_type = optional(string, "t4g.nano")<br/>  })</pre> | `null` | no |
| private\_subnet\_cidrs | IPv4 CIDRs of the private subnets, one per entry of `availability_zones` and in the same order, or empty for none. Each must sit inside `cidr_block` and clear of the public /24s at its start; the upper half of the VPC is a safe place. | `list(string)` | `[]` | no |
| s3\_gateway\_endpoint | Optional S3 gateway endpoint on the private route table, which keeps same-region S3 traffic off the NAT. It needs `private_subnet_cidrs`. `policy` is an endpoint policy JSON document, passed through unchanged; omit it for the AWS default (full access). | <pre>object({<br/>    enabled = bool<br/>    policy  = optional(string)<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| cidr\_block | IPv4 CIDR of the VPC. |
| internet\_gateway\_id | ID of the internet gateway. |
| nat\_instance\_id | ID of the NAT instance. Null without `nat`. |
| nat\_network\_interface\_id | ID of the NAT's network interface, the target of the private route table's default route. Null without `nat`. |
| nat\_public\_ip | Public IPv4 address that traffic from the private subnets leaves from, for allow-lists at the destination. It changes when the NAT instance is replaced. Null without `nat`. |
| nat\_security\_group\_id | ID of the NAT's security group. Null without `nat`. |
| private\_route\_table\_id | ID of the private route table. Null without `private_subnet_cidrs`. |
| private\_subnet\_ids | IDs of the private subnets, in the order of `availability_zones`. Empty without `private_subnet_cidrs`. |
| public\_subnet\_ids | IDs of the public subnets, in the order of `availability_zones`. |
| route\_table\_id | ID of the public route table. |
| s3\_endpoint\_id | ID of the S3 gateway endpoint. Null unless `s3_gateway_endpoint.enabled`. |
| vpc\_id | ID of the VPC, for security groups. |
<!-- END_TF_DOCS -->

## License

[MIT](https://github.com/Jaws-Platform/terraform-aws-jaws-network/blob/main/LICENSE)
