data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name_prefix        = "${var.namespace}-instance"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "instance" {
  statement {
    actions   = ["logs:*", "rds:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "instance" {
  name_prefix = "${var.namespace}-instance"
  role        = aws_iam_role.instance.id
  policy      = data.aws_iam_policy_document.instance.json
}

resource "aws_iam_instance_profile" "instance" {
  name_prefix = "${var.namespace}-instance"
  role        = aws_iam_role.instance.name
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
    name = aws_iam_instance_profile.instance.name
  }

  vpc_security_group_ids = [var.sg.websvr]
}

# Service-linked role that Auto Scaling uses to validate the ELB configuration.
# It is an account-global/singleton resource: create it before the ASG (via depends_on)
# to avoid the "Access denied when attempting to assume role" race when AWS auto-creates the SLR.
# Enable on a NEW account (role does not exist yet); leave false if the role already exists (avoids the "already exists" error).
resource "aws_iam_service_linked_role" "autoscaling" {
  count            = var.create_autoscaling_service_linked_role ? 1 : 0
  aws_service_name = "autoscaling.amazonaws.com"
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
  target_group_arns   = [aws_lb_target_group.webserver.arn]

  # Đảm bảo SLR (nếu được quản) tồn tại & propagate trước khi ASG validate ELB.
  depends_on = [aws_iam_service_linked_role.autoscaling]
}

resource "aws_lb" "this" {
  name               = var.namespace
  load_balancer_type = "application"
  subnets            = var.vpc.public_subnets
  security_groups    = [var.sg.lb]
}

resource "aws_lb_target_group" "webserver" {
  name_prefix = "websvr"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc.vpc_id
  target_type = "instance"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver.arn
  }
}
