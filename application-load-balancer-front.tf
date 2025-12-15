# Application Load Balancer (ALB) and Auto Scaling Group (ASG) in the frontend tier
#   Resources connect to each other in this way:
#     ALB - ALB Listner - Target Group - ASG

# Launch Template so ASG knows how to launch instances
resource "aws_launch_template" "ubuntu20-front" {
  name = "ubuntu20-front"
  instance_type = "t3.micro"
  image_id = data.aws_ami.ubuntu20.image_id
  key_name = var.keypair

  # Put new instances in the security group for frontend tier
  network_interfaces {
    device_index = 0
    security_groups = [aws_security_group.sg-front.id]
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

  # Install apache server and mysql and start the server on port 80
  user_data = filebase64("${path.module}/init.sh")
}

# Auto-Scaling Group to launch instances
resource "aws_autoscaling_group" "front-asg" {
  name = "asg-front"
  min_size = 2
  max_size = 4
  desired_capacity = 2

  # Launch instances in public subnets
  vpc_zone_identifier = [
    aws_subnet.tt-vpc-subnet-public1.id,
    aws_subnet.tt-vpc-subnet-public2.id
  ]

  launch_template {
    id = aws_launch_template.ubuntu20-front.id
    version = "$Latest"
  }

  # Health check
  health_check_grace_period = 300
  health_check_type         = "ELB"

  # Link ASG to ALB's terget group
  target_group_arns = [aws_lb_target_group.front-alb-tg.arn]
}

# Target Group
resource "aws_lb_target_group" "front-alb-tg" {
  name = "alb-front-target-group"
  port = 80
  protocol          = "HTTP"
  vpc_id = aws_vpc.tt-vpc.id
  health_check {
    path = "/"
  }
}

# Listner to forward traffics to target group
resource "aws_lb_listener" "front-alb-listner" {
  # associate with ALB
  load_balancer_arn = aws_lb.front-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    # associate with ASG
    target_group_arn = aws_lb_target_group.front-alb-tg.arn
  }
}

# Application Load Balancer
resource "aws_lb" "front-alb" {
  name = "alb-front"
  internal = false # Should be public facing, so you can access ALB from your browser
  load_balancer_type = "application"

  # Attach the frontend SG to restrict traffics in/out of ALB
  security_groups = [
    aws_security_group.sg-front.id
  ]

  # ALB has it's interfaces on two public subnets
  # It's able to receive/forward traffics from these subnets
  subnets = [
    aws_subnet.tt-vpc-subnet-public1.id,
    aws_subnet.tt-vpc-subnet-public2.id
  ]
}