/* output "web_server_public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "The public IP address of the automated web server"
} */

output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer"
  value       = aws_lb.external_alb.dns_name 
}