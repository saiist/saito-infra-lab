output "alb_arn" { value = aws_lb.this.arn }
output "alb_dns_name" { value = aws_lb.this.dns_name }
output "fqdn" { value = "${var.record_name}.${var.zone_name}" }

output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "primary_target_group_arn" {
  value = aws_lb_target_group.app_blue.arn
}

output "alternate_target_group_arn" {
  value = aws_lb_target_group.app_green.arn
}

output "production_listener_rule_arn" {
  value = aws_lb_listener_rule.prod.arn
}
