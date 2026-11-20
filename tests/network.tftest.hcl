mock_provider "aws" {
  mock_data "aws_default_tags" {
    defaults = {
      tags = {
        Project     = "analytics"
        Environment = "prod"
      }
    }
  }
}

variables {
  name = "acme-analytics"
}

run "a_vpc_without_a_nat_by_default" {
  command = apply

  assert {
    condition     = length(module.nat) == 0
    error_message = "no NAT instance may be created unless nat is set"
  }

  assert {
    condition     = length(output.public_subnet_ids) == 2 && length(output.private_subnet_ids) == 0
    error_message = "the defaults must create one public subnet per zone and no private subnet"
  }

  assert {
    condition     = output.private_route_table_id == null && output.s3_endpoint_id == null
    error_message = "without private subnets there is no private route table and no S3 endpoint"
  }

  assert {
    condition = (
      output.nat_instance_id == null && output.nat_public_ip == null &&
      output.nat_network_interface_id == null && output.nat_security_group_id == null
    )
    error_message = "the NAT outputs must be null without nat"
  }
}

run "private_subnets_without_a_nat" {
  command = apply

  variables {
    private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]
    s3_gateway_endpoint  = { enabled = true }
  }

  assert {
    condition     = length(output.private_subnet_ids) == 2 && output.private_route_table_id != null
    error_message = "private_subnet_cidrs must create one private subnet per zone on one route table"
  }

  assert {
    condition     = output.s3_endpoint_id != null
    error_message = "s3_gateway_endpoint.enabled must create the endpoint"
  }

  assert {
    condition     = length(module.nat) == 0
    error_message = "private subnets alone must not create a NAT instance"
  }
}

run "a_nat_for_the_private_subnets" {
  command = apply

  variables {
    private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]
    nat                  = { ami_id = "ami-0123456789abcdef0" }
  }

  assert {
    condition     = length(module.nat) == 1
    error_message = "nat must create exactly one NAT instance"
  }

  assert {
    condition = (
      output.nat_instance_id == module.nat[0].instance_id &&
      output.nat_public_ip == module.nat[0].public_ip &&
      output.nat_network_interface_id == module.nat[0].network_interface_id &&
      output.nat_security_group_id == module.nat[0].security_group_id
    )
    error_message = "the NAT outputs must be the nat-instance module's outputs"
  }

  assert {
    condition     = output.nat_instance_id != null && output.nat_network_interface_id != null
    error_message = "the NAT outputs must be set with nat"
  }
}

run "a_larger_nat_instance_type_is_passed_through" {
  command = plan

  variables {
    private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]
    nat                  = { ami_id = "ami-0123456789abcdef0", instance_type = "c7g.medium" }
  }

  assert {
    condition     = length(module.nat) == 1
    error_message = "an explicit instance_type must still plan one NAT instance"
  }
}

run "rejects_a_nat_without_private_subnets" {
  command = plan

  variables {
    nat = { ami_id = "ami-0123456789abcdef0" }
  }

  expect_failures = [var.nat]
}

run "rejects_a_name_too_long_for_the_nat" {
  command = plan

  variables {
    name = "a-name-that-is-sixty-one-characters-long-which-is-one-too-man"
  }

  expect_failures = [var.name]
}
