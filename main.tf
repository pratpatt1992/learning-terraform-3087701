data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023.11.20260413.0-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # Amazon
}

resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  subnet_id = module.blog_vpc.public_subnets[0]
  vpc_security_group_ids = [module.blog_sg.security_group_id]

  tags = {
    Name = "HelloWorld"
  }
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "blog_sg" {
source  = "terraform-aws-modules/security-group/aws"
version = "5.3.1"
name   = "blog_new"

vpc_id = module.blog_vpc.vpc_id

ingress_rules = ["http-80-tcp","https-443-tcp","all-all"]
ingress_cidr_blocks = ["0.0.0.0/0"]

egress_rules = ["all-all"]
egress_cidr_blocks = ["0.0.0.0/0"]
}

module "blog_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets

  security_groups = [module.blog_sg.security_group_id]

  listeners = {
    blog-http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_arn = aws_lb_target_group.blog.arn
      }
    }
  }
  tags = {
    Environment = "Dev"
  }
}

resource "aws_lb_target_group" "blog" {
  name     = "blog-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.blog_vpc.vpc_id
}

resource "aws_lb_target_group_attachment" "blog" {
  target_group_arn = aws_lb_target_group.blog.arn
  target_id        = aws_instance.blog.id
  port             = 80
}

# resource "aws_security_group" "blog" {
#   name        = "blog"
#   description = "Allow http and https in. Allow everything out"

#   tags = {
#     terraform = "true"
#   }

#   vpc_id = data.aws_vpc.default.id
# }

# resource "aws_security_group_rule" "blog_http_in" {
# type        = "ingress"
# from_port   = 80
# to_port     = 80
# protocol    = "tcp"
# cidr_blocks = ["0.0.0.0/0"]

# security_group_id = aws_security_group.blog.id
# }

# resource "aws_security_group_rule" "blog_https_in" {
# type        = "ingress"
# from_port   = 443
# to_port     = 443
# protocol    = "tcp"
# cidr_blocks = ["0.0.0.0/0"]

# security_group_id = aws_security_group.blog.id
# }

# resource "aws_security_group_rule" "blog_everything_out" {
# type        = "egress"
# from_port   = 0
# to_port     = 0
# protocol    = -1
# cidr_blocks = ["0.0.0.0/0"]

# security_group_id = aws_security_group.blog.id
# }