terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.71.0"
    }
  }

  backend "s3" {
    bucket = "usedata-states"
    key    = "tf-states/clients/usedata/dev/cluster.tfstate"
    region = "us-west-2"
  }

  required_version = ">= 0.14.0"
}
