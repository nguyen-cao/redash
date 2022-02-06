variable "aws_region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "profile" {
  description = "AWS profile"
  default     = "default"
}

variable "image_tag" {
  description = "Docker Image tag"
  default     = "master"
}

variable "doppler_token" {
  type = string
  description = "A token to authenticate with Doppler"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "desired_count" {
  description = "Desired numbers of instances in the ecs service"
  default     = "1"
}

variable "environment" {
  default     = "dev"
  description = "Environment"
}

variable "client" {
  description = "Client name/id (no space)"
  type        = string
  default = "usedata"
}

variable "team" {
  description = "Team name/id (no space, no underscore)"
  type        = string
  default = "backend"
}

variable "app" {
  description = "App name (no space, no underscore)"
  type        = string
  default = "redash"
}

variable "app_port" {
  description = "App port"
  type        = number
  default = 5000
}
