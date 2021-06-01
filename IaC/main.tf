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
  data = file( "stdPackages.yaml")
  name = "Golden Image Standard Pacakges"
  description = "Install standard packages."
  platform = "Linux"
  version  = "1.0.7"
}

data "aws_imagebuilder_component" "amazonCloudwatchAgentLinux" {
  arn = "arn:aws:imagebuilder:ap-southeast-2:aws:component/amazon-cloudwatch-agent-linux/1.0.0"
}

resource "aws_imagebuilder_image_pipeline" "golden_image" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.golden_image.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.DTA_golden_image.arn
  name                             = "Golden Image"
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
# data "aws_iam_policy" "AWSImageBuilderFullAccess" {
#   arn = "arn:aws:iam::aws:policy/AWSImageBuilderFullAccess"
# }
resource "aws_iam_role" "golden_image" {
  name = "Golden-ImageV6"
  assume_role_policy  = file( "role_policy.json")
  managed_policy_arns=[
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
  ]
}

# EC2InstanceProfileForImageBuilder, EC2InstanceProfileForImageBuilderECRContainerBuilds, and AmazonSSMManagedInstanceCore.

# resource "aws_iam_role_policy_attachment" "golden_image" {
#   role       = aws_iam_role.golden_image.name
#   policy_arn = data.aws_iam_policy.AWSImageBuilderFullAccess.arn
# }

resource "aws_iam_instance_profile" "golden_image" {
  name = aws_iam_role.golden_image.name
  role = aws_iam_role.golden_image.name
}

resource "aws_imagebuilder_image_recipe" "golden_image" {
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

  name         = "golden_image"
  parent_image = "arn:aws:imagebuilder:${var.region}:aws:image/amazon-linux-2-arm64/x.x.x"
  version      = "1.0.6"
  working_directory = "/tmp"
}