module "iam_instance_profile" {
  source  = "terraform-in-action/iip/aws"
  actions = ["logs:*", "rds:*"]
}

data "cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/cloud_config.yaml", var.db_config)
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_launch_template" "webserver" {
  name_prefix   = "${var.namespace}-webserver"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  user_data     = data.cloudinit_config.config.rendered
  key_name      = var.ssh_keypair

  iam_instance_profile {
    name = module.iam_instance_profile.name
  }

  vpc_security_group_ids = [var.sg.websvr]
}

resource "aws_autoscaling_group" "webserver" {
  name_prefix = "${var.namespace}-webserver-asg"
  max_size    = 2
  min_size    = 1

  launch_template {
    id      = aws_launch_template.webserver.id
    version = aws_launch_template.webserver.latest_version
  }

  vpc_zone_identifier = var.vpc.private_subnets
  target_group_arns   = module.alb.target_group_arns
}

module "alb" {
  source             = "terraform-aws-modules/alb/aws"
  version            = "~> 5.0"
  name               = var.namespace
  load_balancer_type = "application"
  vpc_id             = var.vpc.vpc_id
  subnets            = var.vpc.public_subnets
  security_groups    = [var.sg.lb]

  http_tcp_listeners = [{
    port               = 80
    protocol           = "HTTP"
    target_group_index = 0
  }]

  target_groups = [
    {
      name_prefix      = "${var.namespace}-webserver-tg"
      port             = 8080
      protocol         = "HTTP"
      target_type      = "instance"
    }
  ]
}
