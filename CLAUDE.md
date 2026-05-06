# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
terraform init        # required after adding/changing providers
terraform validate    # check configuration is syntactically valid
terraform fmt         # format all .tf files
terraform plan        # preview changes before applying
terraform apply       # deploy infrastructure
terraform destroy     # tear down all resources
```

Target a single resource:
```bash
terraform apply -target=aws_ecs_service.myapp
```

Override a variable at runtime:
```bash
terraform apply -var="desired_count=3" -var="cpu=512"
```

Push a Docker image to ECR (get the URL from outputs):
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)
docker build -t myapp .
docker tag myapp:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest
```

## Architecture

A single-app ECS Fargate deployment with the following traffic flow:

```
Internet → ALB (public subnets) → ECS Tasks (private subnets)
                                        ↓
                                   ECR (image source)
                                   CloudWatch (logs)
```

- **ALB** terminates TLS (self-signed cert via `tls` provider, imported into ACM). Port 80 redirects to 443.
- **ECS Tasks** run in private subnets with no public IPs. Outbound traffic routes through a NAT Gateway.
- **ECR** is in the same region. The task definition references the repository URL dynamically (`aws_ecr_repository.myapp.repository_url`) — no hardcoded account ID.
- **CloudWatch** log group `/ecs/<app_name>` with 7-day retention receives container stdout/stderr via `awslogs` driver.

## File Layout

| File | Purpose |
|---|---|
| `providers.tf` | AWS + TLS provider versions, region via `var.region` |
| `variables.tf` | All input variables with defaults (`region`, `app_name`, `cpu`, `memory`, `desired_count`, `container_port`) |
| `data.tf` | AZ lookup (`data.aws_availability_zones.available`) |
| `main.tf` | All core infrastructure: VPC, subnets, NAT, security groups, ECS, ALB, listeners |
| `certificate.tf` | Self-signed TLS cert generation and ACM import |
| `cloudwatch.tf` | CloudWatch log group |
| `outputs.tf` | `alb_dns_name`, `alb_https_url`, `ecr_repository_url` |

## Key Design Decisions

- **State is local** — no remote backend configured. Intentional for personal/test use.
- **Self-signed certificate** — browser will show a security warning; expected behaviour. The private key is stored in `terraform.tfstate`.
- **`force_delete = true` on ECR** — allows `terraform destroy` to succeed even when images exist in the repository.
- **SSL policy** — `ELBSecurityPolicy-TLS13-1-2-2021-06` enforces TLS 1.2+ with TLS 1.3 support.
- **ECS tasks in private subnets** — `assign_public_ip = false`; only the ALB is internet-facing.
