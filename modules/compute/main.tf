resource "aws_launch_template" "this" {
  name_prefix   = var.name_prefix
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  user_data = var.user_data_base64

  tag_specifications {
    resource_type = "instance"
    tags          = merge({ Name = "${var.name_prefix}instance" }, var.tags)
  }
}

resource "aws_autoscaling_group" "this" {
  name = var.asg_name

  vpc_zone_identifier = var.private_subnet_ids

  target_group_arns = var.target_group_arns

  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "request_count_tracking" {
  name                   = "${var.asg_name}-alb-request-count-policy"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"

      # Combines ALB + Target Group ARN suffixes so CloudWatch knows which traffic to monitor
      resource_label = var.alb_resource_label
    }

    # Scale out when each server handles more than this many requests per minute
    target_value = var.scale_out_request_count
  }
}
