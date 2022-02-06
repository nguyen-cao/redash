terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.71.0"
    }
    doppler = {
      source = "DopplerHQ/doppler"
      version = "1.0.0"
    }
  }

  required_version = ">= 0.14.0"
}