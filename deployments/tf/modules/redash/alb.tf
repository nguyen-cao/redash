module "alb_sg" {
  source = "github.com/nguyen-cao/terraform-aws-security-group.git//modules/http-80"

  name        = "${var.client}-${var.team}-${var.app}-alb-sg"
  description = "Security group with HTTP ports open for everybody (IPv4 CIDR), egress ports are all world open"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
  tags = {
    Name = "${var.client}-${var.team}-${var.app}-alb-sg"
  }
}

module "alb" {
  source = "github.com/nguyen-cao/terraform-aws-alb.git?ref=v6.6.1"

  name = "${var.client}-${var.team}-${var.app}-alb"

  load_balancer_type = "application"

  vpc_id          = data.aws_vpc.vpc.id
  subnets         = [for subnet in data.aws_subnet.public_subnets : subnet.id]
  security_groups = [module.alb_sg.security_group_id]

  target_groups = [
    {
      backend_protocol = "HTTP"
      backend_port     = 5000
      target_type      = "ip"
      health_check = {
        enabled             = true
        interval            = 60
        path                = "/ping"
        port                = 5000
        healthy_threshold   = 3
        unhealthy_threshold = 3
        protocol            = "HTTP"
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
      action_type        = "forward"
    }
  ]

  tags = {
    Client       = var.client
    Team = var.team
    App = var.app
    Environment = var.environment
  }
}