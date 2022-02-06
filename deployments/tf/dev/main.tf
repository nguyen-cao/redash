module "redash" {
  source = "../modules/redash"
  aws_region   = var.aws_region
  environment   = "dev"
  client = var.client
  team = var.team
  desired_count = var.desired_count
  image_tag = var.image_tag
}
