provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "vault_backup" {
    bucket = "vault_daily_backup"
}

resource "aws_security_group" "vault_sg" {
  name        = "vault-sg"
  description = "Allow Vault traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "Vault UI"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "Vault Cluster Communication"
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "vault_lt" {
  name_prefix   = "vault-lt"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  user_data     = file("${path.module}/vault_userdata.sh")

  network_interfaces {
    security_groups = [aws_security_group.vault_sg.id]
  }
}

resource "aws_autoscaling_group" "vault_asg" {
  name                      = "vault-asg"
  min_size                  = 3
  max_size                  = 3
  desired_capacity          = 3
  vpc_zone_identifier       = var.subnet_ids
  launch_template {
    id      = aws_launch_template.vault_lt.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "vault-node"
    propagate_at_launch = true
  }
}

resource "aws_lb" "vault_alb" {
  name               = "vault-alb"
  internal           = true
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.vault_sg.id]
}

resource "aws_lb_target_group" "vault_tg" {
  name     = "vault-tg"
  port     = 8200
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener" "vault_listener" {
  load_balancer_arn = aws_lb.vault_alb.arn
  port              = 8200
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault_tg.arn
  }
}

resource "aws_autoscaling_attachment" "vault_asg_attach" {
  autoscaling_group_name = aws_autoscaling_group.vault_asg.name
  alb_target_group_arn   = aws_lb_target_group.vault_tg.arn
}
