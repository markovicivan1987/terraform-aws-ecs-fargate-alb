output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.myapp.dns_name
}

output "alb_https_url" {
  description = "HTTPS URL of the Application Load Balancer"
  value       = "https://${aws_lb.myapp.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = aws_ecr_repository.myapp.repository_url
}
