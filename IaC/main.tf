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

provider "aws" {
  region=var.region
}

resource "aws_imagebuilder_component" "stdPackages" {
  data = file( "stdPackages.yaml")
  name = "stdPackages"
  description = "Install standard packages."
  platform = "Linux"
  version  = "1.0.6"
}

resource "aws_imagebuilder_image" "DTA_golden_image" {
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.golden_image.arn
  image_recipe_arn                 = aws_imagebuilder_image_recipe.DTA_golden_image.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.DTA_golden_image.arn
}

resource "aws_imagebuilder_infrastructure_configuration" "DTA_golden_image" {
  description                   = "Golden image"
  instance_profile_name         = aws_iam_instance_profile.golden_image.name
  name                          = "DTA_golden_image"
  terminate_instance_on_failure = true

  tags = {
    foo = "bar"
  }
}

resource "aws_iam_instance_profile" "golden_image" {
  name = "Golden-ImageV2"
  role = "EC2InstanceProfileForImageBuilder"
}

# resource "aws_iam_role" "role" {
#   name = "test_role"
#   path = "/"

#   assume_role_policy = <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Action": "sts:AssumeRole",
#             "Principal": {
#                "Service": "ec2.amazonaws.com"
#             },
#             "Effect": "Allow",
#             "Sid": ""
#         }
#     ]
# }
# EOF
# }

resource "aws_imagebuilder_distribution_configuration" "golden_image" {
  name = "Golden Image"

  distribution {
    ami_distribution_configuration {
      ami_tags = {
        CostCenter = "IT"
      }

      name = "golden-image-{{ imagebuilder:buildDate }}"

    }

    region = var.region
  }
}

resource "aws_imagebuilder_image_recipe" "DTA_golden_image" {
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

  name         = "DTA_minimum_packages"
  parent_image = "arn:aws:imagebuilder:${var.region}:aws:image/amazon-linux-2-arm64/x.x.x"
  version      = "1.0.2"
  working_directory = "/tmp"
}