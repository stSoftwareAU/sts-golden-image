terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  region="ap-southeast-2"
}

resource "aws_imagebuilder_component" "stdPackages" {
  data = yamlencode({
    
    phases = [{
      name = "build"
      steps = [{
        name = "updateYUM"
        action = "ExecuteBash"
        inputs = {
          commands = ["yum update -y"]
        }
      },
      {
        name = "installDocker"
        action = "ExecuteBash"
        inputs = {
          commands = [
            "amazon-linux-extras install docker",
            "service docker start",
            "usermod -a -G docker ec2-user"
          ]
        }
      },
      {
        name = "installJQ"
        action = "ExecuteBash"
        inputs = {
          commands = [
            "yum install jq -y"
          ]
        }
      }
      ]
    },{
      name= "validate"
      steps =[{
        name = "HelloWorldStep"
        action = "ExecuteBash"
        inputs = {
          commands = ["echo \"Hello World! Validate.\""]
        }
      }]
    },{
      name= "test"
      steps =[{
        name = "testDocker"
        action = "ExecuteBash"
        inputs = {
          commands = ["docker info"]
        }
      },{
        name = "testJQ"
        action = "ExecuteBash"
        inputs = {
          commands = ["jq -help"]
        }
      }]
    }]
    schemaVersion = 1.0
  })
  name     = "stdPackaces"
  description = "Install standard packages."
  platform = "Linux"
  version  = "1.0.1"
}