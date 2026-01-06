# Week 3-4: Infrastructure as Code & AWS Services

## Learning Objectives
- Master Terraform fundamentals
- Deploy AWS infrastructure programmatically
- Understand Docker containerization
- Learn Kubernetes basics

## Daily Tasks

### Day 1: Terraform Basics
- [ ] Install Terraform and configure AWS provider
- [ ] Learn HCL syntax and basic resources
- [ ] Practice: Create VPC with Terraform
- [ ] Understand state management

### Day 2: AWS Core Services Deep Dive
- [ ] Deploy EC2 instances with Terraform
- [ ] Configure Security Groups and NACLs
- [ ] Set up S3 buckets and IAM roles
- [ ] Practice: Multi-tier architecture

### Day 3: Docker Fundamentals
- [ ] Install Docker and understand containers
- [ ] Write Dockerfiles and build images
- [ ] Learn Docker networking and volumes
- [ ] Practice: Containerize a web application

### Day 4: Container Orchestration
- [ ] Install kubectl and minikube
- [ ] Learn Kubernetes pods, services, deployments
- [ ] Practice: Deploy containerized app to K8s
- [ ] Understand ConfigMaps and Secrets

### Day 5: Infrastructure Automation
- [ ] Create Terraform modules
- [ ] Implement remote state with S3
- [ ] Practice: Deploy EKS cluster
- [ ] Set up monitoring with CloudWatch

## Hands-on Lab: Deploy 3-Tier Architecture

```hcl
# main.tf
provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"
  cidr_block = "10.0.0.0/16"
}

module "web_tier" {
  source = "./modules/ec2"
  subnet_ids = module.vpc.public_subnet_ids
  instance_type = "t3.micro"
}
```

## Assessment
- [ ] Deploy complete infrastructure with Terraform
- [ ] Containerize and deploy application
- [ ] Set up basic monitoring
- [ ] Document architecture decisions
