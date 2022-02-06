variable "aws_region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "image_tag" {
  description = "Docker Image tag"
  default     = "master"
}

variable "desired_count" {
  description = "Desired numbers of instances in the ecs service"
  default     = "1"
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

variable "doppler_token" {
  type = string
  description = "A token to authenticate with Doppler"
}
