resource "aws_launch_template" "ubuntu20-back" {
  name = "ubuntu20-back"
  instance_type = "t3.micro"
  image_id = data.aws_ami.ubuntu20.image_id
  key_name = var.keypair

  network_interfaces {
    device_index = 0
    security_groups = [aws_security_group.sg-back.id]
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type = "gp2"
      volume_size = 8
      delete_on_termination = true

    }
  }
  user_data = filebase64("${path.module}/init.sh")
}

resource "aws_autoscaling_group" "back-asg" {
  name = "asg-back"
  min_size = 2
  max_size = 4
  desired_capacity = 2

  vpc_zone_identifier = [
    aws_subnet.tt-vpc-subnet-private1.id,
    aws_subnet.tt-vpc-subnet-private2.id
  ]

  launch_template {
    id = aws_launch_template.ubuntu20-back.id
    version = aws_launch_template.ubuntu20-front.latest_version
  }

  health_check_grace_period = 300
  health_check_type         = "ELB"

  target_group_arns = [aws_lb_target_group.back-alb-tg.arn]
}

resource "aws_lb" "back-alb" {
  name = "alb-back"
  internal = true 
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.sg-back.id
  ]
  subnets = [
    aws_subnet.tt-vpc-subnet-private1.id,
    aws_subnet.tt-vpc-subnet-private2.id
  ]
}

resource "aws_lb_listener" "back-alb-listner" {
  load_balancer_arn = aws_lb.back-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.back-alb-tg.arn
  }
}

resource "aws_lb_target_group" "back-alb-tg" {
  name = "alb-back-target-group"
  port = 80
  protocol          = "HTTP"
  vpc_id = aws_vpc.tt-vpc.id
  health_check {
    path = "/"
  }
}