terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.39"
    }
  }

  required_version = ">= 0.14.9"
}

variable "region"{
  type        = string
  description = "The AWS region"
}

variable "area"{
  type        = string
  description = "The Area"
}

variable "semanticVersion"{
  type        = string
  description = "The Area"
  default="1.0.8"
}

provider "aws" {
  region=var.region
  default_tags {
    tags = {
      Environment = var.area
      Name        = "Golden Image"
    }
  }
}

resource "aws_imagebuilder_component" "stdPackages" {
  data = replace( file( "stdPackages.yaml"),"$${REGION}", var.region)
  name = "Golden Image Standard Pacakges"
  description = "Install standard packages."
  platform = "Linux"
  version  = var.semanticVersion
}

data "aws_imagebuilder_component" "amazonCloudwatchAgentLinux" {
  arn = "arn:aws:imagebuilder:ap-southeast-2:aws:component/amazon-cloudwatch-agent-linux/1.0.0"
}

data "aws_imagebuilder_component" "updateLinux" {
  arn = "arn:aws:imagebuilder:ap-southeast-2:aws:component/update-linux/x.x.x"
}
    
data "aws_imagebuilder_component" "bootTest" {
  arn =  "arn:aws:imagebuilder:${var.region}:aws:component/simple-boot-test-linux/1.0.0/1"
}
data "aws_imagebuilder_component" "rebootTest" {
  arn = "arn:aws:imagebuilder:${var.region}:aws:component/reboot-test-linux/1.0.0/1"
}

resource "aws_imagebuilder_image_pipeline" "golden_image_arm64" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.golden_image_arm64.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.DTA_golden_image.arn
  name                             = "Golden Image ARM64"
  description = "Golden Image for launching of all other instances"

  schedule {
    schedule_expression = "cron(0 9 * * ? *)"
  }
}

resource "aws_imagebuilder_image_pipeline" "golden_image_x86" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.golden_image_x86.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.DTA_golden_image.arn
  name                             = "Golden Image X86"
  description = "Golden Image for launching of all other instances"

  schedule {
    schedule_expression = "cron(0 9 * * ? *)"
  }
}

resource "aws_imagebuilder_infrastructure_configuration" "DTA_golden_image" {
  description                   = "Golden image"
  instance_profile_name         = aws_iam_instance_profile.golden_image.name
  name                          = "DTA_golden_image"
  terminate_instance_on_failure = true
}

resource "aws_iam_role" "golden_image" {
  name = "Golden-ImageV6"
  assume_role_policy  = file( "role_policy.json")
  managed_policy_arns=[
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

  name         = "golden_image-arm64"
  parent_image = "arn:aws:imagebuilder:${var.region}:aws:image/amazon-linux-2-arm64/x.x.x"
  version      = var.semanticVersion
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

  name         = "golden_image-x86"
  parent_image = "arn:aws:imagebuilder:${var.region}:aws:image/amazon-linux-2-x86/x.x.x"
  version      = var.semanticVersion
  working_directory = "/tmp"
}