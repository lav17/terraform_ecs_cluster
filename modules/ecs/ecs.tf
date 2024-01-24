
resource "aws_ecs_cluster" "demo_app_cluster" {
  name = var.demo_app_cluster_name
}

#creating ec2 to launch containers on

data "aws_vpc" "default" {
  default = true
}


data "aws_subnets" "example" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


#policy to assume roles
data "aws_iam_policy_document" "ecs_node_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

#create a role that assumes role
resource "aws_iam_role" "ecs_node_role" {
  name_prefix        = "demo-ecs-node-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_node_doc.json
}


#attach policy to role
resource "aws_iam_role_policy_attachment" "ecs_node_role_policy" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

#to attach role to ec2
resource "aws_iam_instance_profile" "ecs_node" {
  name_prefix = "demo-ecs-node-profile"
  role        = aws_iam_role.ecs_node_role.name
}

#create ec2 node
data "aws_ssm_parameter" "ecs_node_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_security_group" "ec2_sg" {
  name = "ec2_sg"
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.lb_sg.name]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "ecs_ec2" {
  name_prefix   = "demo-ecs-ec2-node"
  image_id      = data.aws_ssm_parameter.ecs_node_ami.value
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }
  key_name = "demo"

  iam_instance_profile { arn = aws_iam_instance_profile.ecs_node.arn }
  monitoring { enabled = true }

  user_data = base64encode(<<-EOF
      #!/bin/bash
      echo ECS_CLUSTER=${aws_ecs_cluster.demo_app_cluster.name} >> /etc/ecs/ecs.config;
    EOF
  )
}

#ASG

resource "aws_autoscaling_group" "ecs" {
  name_prefix = "demo-ecs-asg-node"
  vpc_zone_identifier = [
    element(data.aws_subnets.example.ids, 0),
    element(data.aws_subnets.example.ids, 1),
  ]

  min_size                  = 1
  max_size                  = 1
  health_check_grace_period = 0
  health_check_type         = "EC2"
  protect_from_scale_in     = false

  launch_template {
    id      = aws_launch_template.ecs_ec2.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "demo-ecs-cluster"
    propagate_at_launch = true
  }

}

#attaching ASG to ECS

resource "aws_ecs_capacity_provider" "demo_ecs" {
  name = "demo-ecs"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.demo_app_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.demo_ecs.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.demo_ecs.name
    base              = 1
    weight            = 100
  }
}


#task definition
resource "aws_ecs_task_definition" "demo-ecs-task" {
  family = "demo-ecs-task"
  container_definitions = jsonencode([
    {
      name      = "ecs-demo-app"
      image     = "${var.ecr_repo_url}"
      cpu       = 10
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])

}


#aws ecs service
resource "aws_ecs_service" "demo-ecs" {
  name            = "demo-ecs-service"
  cluster         = aws_ecs_cluster.demo_app_cluster.id
  task_definition = aws_ecs_task_definition.demo-ecs-task.arn
  launch_type     = "EC2"
  desired_count   = 1
  load_balancer {
    target_group_arn = aws_lb_target_group.demo-ecs-lb-tg.arn
    container_name   = "ecs-demo-app"
    container_port   = 3000
  }
  depends_on = [aws_lb.demo-ecs-lb]
}


#load balancer
resource "aws_security_group" "lb_sg" {
  name = "lb_sg"
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = [var.TF_VAR_CLOUDFRONT_IP]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_lb" "demo-ecs-lb" {
  name               = "demo-ecs-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets = [
    element(data.aws_subnets.example.ids, 0),
  element(data.aws_subnets.example.ids, 1), ]

}


resource "aws_lb_target_group" "demo-ecs-lb-tg" {
  vpc_id   = data.aws_vpc.default.id
  protocol = "HTTP"
  port     = 80

  health_check {
    enabled             = true
    path                = "/"
    port                = 80
    matcher             = 200
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.demo-ecs-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo-ecs-lb-tg.id
  }
}


locals {
  ecs-demo = "ecs-demo-app"
}
#cloudfront
resource "aws_cloudfront_distribution" "ecs-alb_distribution" {
  origin {
    domain_name = aws_lb.demo-ecs-lb.dns_name
    origin_id   = local.ecs-demo

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }



  enabled = true

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.ecs-demo

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

