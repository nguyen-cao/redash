provider "aws" {
  region  = var.aws_region
}
module "redash" {
  source = "../modules/redash"
  aws_region   = var.aws_region
  doppler_token = var.doppler_token
  environment   = "dev"
  client = var.client
  team = var.team
  desired_count = var.desired_count
  image_tag = var.image_tag
}
