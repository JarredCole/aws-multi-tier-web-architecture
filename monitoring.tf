# ==========================================
# 1. SNS TOPIC & EMAIL SUBSCRIPTION FOR ALERTS
# ==========================================

resource "aws_sns_topic" "alerts" {
  name = "cloudwatch-infrastructure-alerts"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "dj.cole710@gmail.com" # Replace with your email address
}

# ==========================================
# 2. CLOUDWATCH ALARM: HIGH EC2 CPU USAGE
# ==========================================

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "asg-high-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 # Evaluates every 5 minutes
  statistic           = "Average"
  threshold           = 80 # Triggers if CPU reaches 80%
  alarm_description   = "Triggers when Auto Scaling Group CPU exceeds 80% for 10 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name # References your existing ASG resource
  }
}

# ==========================================
# 3. CLOUDWATCH ALARM: ALB HTTP 5XX ERRORS
# ==========================================

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "alb-high-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60 # Evaluates every 1 minute
  statistic           = "Sum"
  threshold           = 5 # Triggers if there are more than 5 server errors
  alarm_description   = "Triggers when the Application Load Balancer detects HTTP 5xx errors."
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.external_alb.arn_suffix # References your existing ALB resource
  }
}

# ==========================================
# 4. CLOUDWATCH DASHBOARD
# ==========================================

resource "aws_cloudwatch_dashboard" "main_dashboard" {
  dashboard_name = "Infrastructure-Health-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.web_asg.name]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "ASG Average CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.external_alb.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.external_alb.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = "us-east-1"
          title  = "ALB Traffic & 5xx Server Errors"
        }
      }
    ]
  })
}