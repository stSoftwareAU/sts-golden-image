terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.63"
    }
  }

  required_version = ">= 0.14.9"
}

variable "semanticVersion" {
  type        = string
  description = "The version number"
  default     = "1.0.11"
}

/**
 * Standard variables
 */
variable "area" {
  type        = string
  description = "The Area"
}

variable "department" {
  type        = string
  description = "The Department"
}

variable "region" {
  type        = string
  description = "The AWS region"
}

variable "package" {
  type        = string
  description = "The Package"
  default     = "Unknown"
}

variable "who" {
  type        = string
  description = "Who did deployment"
  default     = "Unknown"
}

variable "digest" {
  type        = string
  description = "The docker image Digest"
  default     = "Unknown"
}

/* AWS provider and default tags */
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Package    = var.package
      Area       = var.area
      Department = var.department
      Who        = var.who
      Digest     = var.digest
    }
  }
}

data "aws_vpc" "main" {

  filter {
    name   = "tag:Name"
    values = ["Main"]
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.main.id

  filter {
    name   = "tag:Type"
    values = ["PRIVATE"]
  }
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = data.aws_vpc.main.id
}

resource "aws_imagebuilder_component" "stdPackages" {
  data        = replace(file("stdPackages.yaml"), "$${REGION}", var.region)
  name        = "Golden Image Standard Pacakges"
  description = "Install standard packages."
  platform    = "Linux"
  version     = var.semanticVersion
}

data "aws_imagebuilder_component" "amazonCloudwatchAgentLinux" {
  arn = "arn:aws:imagebuilder:ap-southeast-2:aws:component/amazon-cloudwatch-agent-linux/1.0.0"
}

data "aws_imagebuilder_component" "updateLinux" {
  arn = "arn:aws:imagebuilder:ap-southeast-2:aws:component/update-linux/x.x.x"
}

data "aws_imagebuilder_component" "bootTest" {
  arn = "arn:aws:imagebuilder:${var.region}:aws:component/simple-boot-test-linux/1.0.0/1"
}
data "aws_imagebuilder_component" "rebootTest" {
  arn = "arn:aws:imagebuilder:${var.region}:aws:component/reboot-test-linux/1.0.0/1"
}

resource "aws_imagebuilder_image_pipeline" "golden_image_arm64" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.golden_image_arm64.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.golden_image.arn
  name                             = "Golden Image ARM64"
  description                      = "Golden Image for launching of all other instances"

  schedule {
    schedule_expression = "cron(37 2 ? * tue)"
  }
}

resource "aws_imagebuilder_image_pipeline" "golden_image_x86" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.golden_image_x86.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.golden_image.arn
  name                             = "Golden Image X86"
  description                      = "Golden Image for launching of all other instances"

  schedule {
    schedule_expression = "cron(36 2 ? * tue)"
  }
}

resource "aws_imagebuilder_infrastructure_configuration" "golden_image" {
  description                   = "Golden image"
  instance_profile_name         = aws_iam_instance_profile.golden_image.name
  name                          = join("-", [upper(var.department), "golden_image", lower(var.area)])
  terminate_instance_on_failure = true
  subnet_id                     = tolist(data.aws_subnet_ids.private.ids)[0]
  security_group_ids            = [data.aws_security_group.default.id]
}

resource "aws_iam_role" "golden_image" {
  name               = join("-", [lower(var.department), join("@", ["golden_image", lower(var.area)])])
  assume_role_policy = file("role_policy.json")
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
  ]
}

resource "aws_iam_instance_profile" "golden_image" {
  name = aws_iam_role.golden_image.name
  role = aws_iam_role.golden_image.name
}

resource "aws_imagebuilder_image_recipe" "golden_image_arm64" {
  block_device_mapping {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 8
      volume_type           = "gp2"
      encrypted             = true
    }
  }

  component {
    component_arn = aws_imagebuilder_component.stdPackages.arn
  }

  component {
    component_arn = data.aws_imagebuilder_component.amazonCloudwatchAgentLinux.arn
  }

  component {
    component_arn = data.aws_imagebuilder_component.updateLinux.arn
  }

  component {
    component_arn = data.aws_imagebuilder_component.bootTest.arn
  }

  component {
    component_arn = data.aws_imagebuilder_component.rebootTest.arn
  }

  name              = "golden_image-arm64"
  parent_image      = "arn:aws:imagebuilder:${var.region}:aws:image/amazon-linux-2-arm64/x.x.x"
  version           = var.semanticVersion
  working_directory = "/tmp"
}

resource "aws_imagebuilder_image_recipe" "golden_image_x86" {
  block_device_mapping {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 8
      volume_type           = "gp2"
    }
  }

  component {
    component_arn = aws_imagebuilder_component.stdPackages.arn
  }

  component {
    component_arn = data.aws_imagebuilder_component.amazonCloudwatchAgentLinux.arn
  }

  component {
    component_arn = data.aws_imagebuilder_component.updateLinux.arn
  }

  component {
    component_arn = data.aws_imagebuilder_component.bootTest.arn
  }

  component {
    component_arn = data.aws_imagebuilder_component.rebootTest.arn
  }

  name              = "golden_image-x86"
  parent_image      = "arn:aws:imagebuilder:${var.region}:aws:image/amazon-linux-2-x86/x.x.x"
  version           = var.semanticVersion
  working_directory = "/tmp"
}