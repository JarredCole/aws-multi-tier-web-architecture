
# 1. Create the ALB Security Group (Allows Public Traffic)
# tfsec:ignore:aws-ec2-no-public-ingress-sgr

resource "aws_security_group" "alb_sg" {
  name        = "production-alb-sg"
  description = "Allows public HTTP traffic to the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:aws-ec2-no-public-ingress-sgr
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:aws-ec2-no-public-egress-sgr
  }

  tags = {
    Name = "production-alb-sg"
  }
}

# 2. Create the Web Server Security Group (Restricted to ALB)
resource "aws_security_group" "web_sg" {
  name        = "production-web-sg"
  description = "Allows traffic ONLY from the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow HTTP only from ALB Security Group"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # <- Zero-Trust Lock
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:aws-ec2-no-public-egress-sgr
  }

  tags = {
    Name = "production-web-sg"
  }
}

# 3. Fetch the Latest Amazon Linux 2023 AMI Dynamically
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# 4. Create the EC2 Instance in Public Subnet A
/*resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  subnet_id     = aws_subnet.public_a.id

  # Attach our locked-down security group
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Automatically install Apache and set up "Hello World" on launch
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install httpd -y
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello World from the Automated Infrastructure Phase!</h1>" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name = "production-app-A"
  }
} */

# 4. Define the Launch Template (The Blueprint for your Servers)
resource "aws_launch_template" "web_launch_template" {
  name_prefix   = "web-server-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t2.micro"

  # Attach your existing Security Group (Note: it uses a block inside a list here)
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Attach your existing IAM Instance Profile for SSM permissions
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  # Your automated user data script encoded in base64 (required for Launch Templates)
  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install httpd -y
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello World from the Automated Infrastructure Phase!</h1>" | sudo tee /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "production-asg-worker"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 5. Define the Auto Scaling Group (The Engine)
resource "aws_autoscaling_group" "web_asg" {
  name_prefix         = "production-asg-"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id] # Spreads instances across both subnets

  # Link the ASG to your existing Launch Template
  launch_template {
    id      = aws_launch_template.web_launch_template.id
    version = "$Latest"
  }

  # Automatically tie your ASG workers straight into your ALB Target Group!
  target_group_arns = [aws_lb_target_group.web_target_group.arn]

  # Use ALB health checks instead of basic EC2 hardware checks
  health_check_type         = "ELB"
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }
}

# 6. Create the IAM Role for EC2
resource "aws_iam_role" "ec2_ssm_role" {
  name = "production-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 7. Attach the Core SSM Policy to the Role
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 8. Create the Instance Profile that EC2 can actually use
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# tfsec:ignore:aws-elb-alb-not-public

# 9. Define the Application Load Balancer
# tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "external_alb" {
  name               = "production-alb"
  internal           = false
  load_balancer_type = "application"
  drop_invalid_header_fields = true # Fixes Result #5 (HIGH)
  security_groups    = [aws_security_group.alb_sg.id] # Make sure this matches your ALB SG name
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id] # Must span at least 2 public subnets

  tags = {
    Name = "production-alb"
  }
}

# In compute.tf -> aws_launch_template.web_launch_template
resource "aws_launch_template" "web_launch_template" {
  name_prefix   = "web-server-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Fixes Result #7 (HIGH) - Enforce IMDSv2 Token Requirement
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}

# 10. Define the Target Group
resource "aws_lb_target_group" "web_target_group" {
  name     = "web-server-target-group"
  port     = 80
  protocol = "HTTP" # tfsec:ignore:aws-elb-http-not-used
  vpc_id   = aws_vpc.main.id # Make sure this matches your VPC resource name

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 11. Define the HTTP Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }
}

/* # 12. Attach your EC2 Instance to the Target Group
resource "aws_lb_target_group_attachment" "web_attachment" {
  target_group_arn = aws_lb_target_group.web_target_group.arn
  target_id        = aws_instance.web_server.id
  port             = 80
} */