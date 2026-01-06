# Week 3-4: Infrastructure as Code & AWS Services

## Learning Objectives
- Master Terraform fundamentals
- Deploy AWS infrastructure programmatically
- Understand Docker containerization
- Learn Kubernetes basics

## Daily Tasks

### Day 1: Terraform Fundamentals

#### What is Infrastructure as Code (IaC)?
IaC treats infrastructure like software code - version controlled, repeatable, and automated. Terraform is the leading IaC tool that works with multiple cloud providers.

#### Terraform Core Concepts:
- **Providers**: Plugins for cloud services (AWS, Azure, GCP)
- **Resources**: Infrastructure components (EC2, S3, VPC)
- **State**: Terraform's record of your infrastructure
- **Modules**: Reusable infrastructure components

#### Installation and Setup:
```bash
# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version

# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Key, region (us-east-1), output format (json)
```

#### Your First Terraform Configuration:
```hcl
# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "terraform-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-igw"
  }
}

# Create public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-public-subnet"
  }
}

# Output values
output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.public.id
}
```

#### Terraform Workflow:
```bash
# Initialize Terraform (download providers)
terraform init

# Validate configuration
terraform validate

# Plan changes (dry run)
terraform plan

# Apply changes
terraform apply
# Type 'yes' when prompted

# View current state
terraform show
terraform state list

# Destroy infrastructure
terraform destroy
# Type 'yes' when prompted
```

#### Variables and Outputs:
```hcl
# variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# terraform.tfvars
aws_region  = "us-east-1"
vpc_cidr    = "10.0.0.0/16"
environment = "dev"
```

**Tasks:**
- [ ] Install Terraform and configure AWS credentials
- [ ] Create and apply the VPC configuration above
- [ ] Practice terraform plan, apply, and destroy
- [ ] Add variables and use terraform.tfvars

### Day 2: AWS Core Services Deep Dive

#### EC2 (Elastic Compute Cloud) with Terraform:
```hcl
# security-group.tf
resource "aws_security_group" "web" {
  name_prefix = "web-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict this in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-security-group"
  }
}

# ec2.tf
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")  # Generate with: ssh-keygen -t rsa
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name              = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id             = aws_subnet.public.id

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Terraform!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "terraform-web-server"
  }
}

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}
```

#### S3 Bucket Configuration:
```hcl
# s3.tf
resource "aws_s3_bucket" "app_bucket" {
  bucket = "my-terraform-app-bucket-${random_string.bucket_suffix.result}"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "app_bucket_versioning" {
  bucket = aws_s3_bucket.app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_bucket_encryption" {
  bucket = aws_s3_bucket.app_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Upload a file to S3
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "index.html"
  source = "index.html"
  etag   = filemd5("index.html")
}
```

#### IAM Roles and Policies:
```hcl
# iam.tf
resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-access-role"

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

resource "aws_iam_policy" "s3_access" {
  name        = "s3-access-policy"
  description = "Policy for S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.app_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_role.name
}
```

#### Multi-Tier Architecture Example:
```hcl
# Create private subnet for database
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "terraform-private-subnet"
  }
}

# Database security group
resource "aws_security_group" "database" {
  name_prefix = "db-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  tags = {
    Name = "database-security-group"
  }
}

# RDS subnet group
resource "aws_db_subnet_group" "main" {
  name       = "main-subnet-group"
  subnet_ids = [aws_subnet.public.id, aws_subnet.private.id]

  tags = {
    Name = "Main DB subnet group"
  }
}

# RDS instance
resource "aws_db_instance" "main" {
  identifier     = "terraform-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  
  allocated_storage = 20
  storage_type      = "gp2"
  
  db_name  = "appdb"
  username = "admin"
  password = "changeme123!"  # Use AWS Secrets Manager in production
  
  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  skip_final_snapshot = true
  
  tags = {
    Name = "terraform-database"
  }
}
```

**Tasks:**
- [ ] Deploy EC2 instance with security group
- [ ] Create S3 bucket with encryption
- [ ] Set up IAM roles and policies
- [ ] Build the multi-tier architecture above

### Day 3: Docker Fundamentals

#### Why Docker for DevOps?
Docker solves the "it works on my machine" problem by packaging applications with all dependencies into portable containers. Essential for modern DevOps workflows.

#### Docker Core Concepts:
- **Image**: Read-only template for creating containers
- **Container**: Running instance of an image
- **Dockerfile**: Instructions to build an image
- **Registry**: Storage for Docker images (Docker Hub, ECR)

#### Docker Installation and Setup:
```bash
# Install Docker on Ubuntu
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (avoid sudo)
sudo usermod -aG docker $USER
# Log out and back in for changes to take effect

# Verify installation
docker --version
docker run hello-world
```

#### Basic Docker Commands:
```bash
# Pull and run images
docker pull nginx:alpine          # Download image
docker images                     # List local images
docker run -d -p 8080:80 nginx:alpine  # Run container in background
docker ps                         # List running containers
docker ps -a                      # List all containers

# Container management
docker stop container_id          # Stop container
docker start container_id         # Start stopped container
docker restart container_id       # Restart container
docker rm container_id            # Remove container
docker rmi image_id              # Remove image

# Execute commands in containers
docker exec -it container_id /bin/sh  # Interactive shell
docker logs container_id          # View container logs
```

#### Writing Dockerfiles:
```dockerfile
# Dockerfile for Node.js application
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001
USER nextjs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["npm", "start"]
```

#### Multi-Stage Dockerfile Example:
```dockerfile
# Multi-stage build for React application
# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production
FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

#### Docker Networking:
```bash
# Create custom network
docker network create app-network

# Run containers on same network
docker run -d --name database --network app-network postgres:13
docker run -d --name webapp --network app-network -p 8080:80 my-web-app

# List networks
docker network ls

# Inspect network
docker network inspect app-network
```

#### Docker Volumes:
```bash
# Named volumes (managed by Docker)
docker volume create app-data
docker run -d -v app-data:/data postgres:13

# Bind mounts (host directory)
docker run -d -v /host/path:/container/path nginx:alpine

# Temporary volumes
docker run -d --tmpfs /tmp nginx:alpine

# List volumes
docker volume ls
docker volume inspect app-data
```

#### Practical Docker Lab:
```bash
# 1. Create a simple web application
mkdir docker-lab && cd docker-lab

# Create a simple HTML file
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Docker Lab</title>
</head>
<body>
    <h1>Hello from Docker!</h1>
    <p>Container ID: <span id="container-id"></span></p>
    <script>
        fetch('/api/hostname')
            .then(response => response.text())
            .then(data => {
                document.getElementById('container-id').textContent = data;
            });
    </script>
</body>
</html>
EOF

# Create a simple Node.js server
cat > server.js << 'EOF'
const express = require('express');
const os = require('os');
const app = express();
const port = 3000;

app.use(express.static('.'));

app.get('/api/hostname', (req, res) => {
    res.send(os.hostname());
});

app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
EOF

# Create package.json
cat > package.json << 'EOF'
{
  "name": "docker-lab",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.0"
  },
  "scripts": {
    "start": "node server.js"
  }
}
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
EOF

# Build and run the application
docker build -t my-web-app .
docker run -d -p 3000:3000 --name web-app my-web-app

# Test the application
curl http://localhost:3000
curl http://localhost:3000/api/hostname

# View logs
docker logs web-app

# Clean up
docker stop web-app
docker rm web-app
```

#### Docker Compose Introduction:
```yaml
# docker-compose.yml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DB_HOST=database
    depends_on:
      - database
    networks:
      - app-network

  database:
    image: postgres:13
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-network

volumes:
  db-data:

networks:
  app-network:
    driver: bridge
```

```bash
# Docker Compose commands
docker-compose up -d          # Start services in background
docker-compose ps             # List services
docker-compose logs web       # View service logs
docker-compose exec web sh    # Execute command in service
docker-compose down           # Stop and remove services
```

**Tasks:**
- [ ] Install Docker and run hello-world
- [ ] Build the web application from the lab above
- [ ] Practice Docker networking and volumes
- [ ] Create a docker-compose.yml for multi-service app

### Day 4: Kubernetes Fundamentals

#### Why Kubernetes for DevOps?
Kubernetes orchestrates containers at scale, providing automated deployment, scaling, and management. Essential for modern cloud-native applications.

#### Kubernetes Core Concepts:
- **Pod**: Smallest deployable unit (one or more containers)
- **Service**: Network endpoint to access pods
- **Deployment**: Manages pod replicas and updates
- **Namespace**: Virtual cluster for resource isolation

#### Installation and Setup:
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install minikube for local development
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube /usr/local/bin/

# Start minikube cluster
minikube start --driver=docker
kubectl cluster-info
```

#### Your First Pod:
```yaml
# pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

```bash
# Deploy and manage pods
kubectl apply -f pod.yaml
kubectl get pods
kubectl describe pod nginx-pod
kubectl logs nginx-pod
kubectl exec -it nginx-pod -- /bin/sh
kubectl delete pod nginx-pod
```

#### Deployments for Production:
```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### Services for Networking:
```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  type: LoadBalancer
---
# ClusterIP service (internal)
apiVersion: v1
kind: Service
metadata:
  name: nginx-internal
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

#### ConfigMaps and Secrets:
```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_url: "postgresql://localhost:5432/myapp"
  log_level: "info"
  nginx.conf: |
    server {
        listen 80;
        location / {
            proxy_pass http://backend:3000;
        }
    }
---
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  username: YWRtaW4=  # base64 encoded 'admin'
  password: cGFzc3dvcmQ=  # base64 encoded 'password'
```

#### Complete Application Example:
```yaml
# web-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-app
        image: nginx:alpine
        ports:
        - containerPort: 80
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_url
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: password
        volumeMounts:
        - name: config-volume
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: config-volume
        configMap:
          name: app-config
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

#### Kubernetes Commands Cheat Sheet:
```bash
# Cluster management
kubectl cluster-info
kubectl get nodes
kubectl get namespaces

# Pod management
kubectl get pods -o wide
kubectl describe pod <pod-name>
kubectl logs <pod-name> -f
kubectl exec -it <pod-name> -- /bin/bash

# Deployment management
kubectl get deployments
kubectl scale deployment nginx-deployment --replicas=5
kubectl rollout status deployment/nginx-deployment
kubectl rollout history deployment/nginx-deployment
kubectl rollout undo deployment/nginx-deployment

# Service management
kubectl get services
kubectl expose deployment nginx-deployment --port=80 --type=LoadBalancer

# Resource management
kubectl apply -f .
kubectl delete -f deployment.yaml
kubectl get all
```

**Tasks:**
- [ ] Install kubectl and minikube
- [ ] Deploy the nginx pod and deployment above
- [ ] Create services and test connectivity
- [ ] Practice with ConfigMaps and Secrets

### Day 5: Infrastructure Automation & Monitoring

#### Infrastructure Automation with Terraform Modules:
Modules make Terraform code reusable, maintainable, and follow DRY principles. Essential for managing infrastructure at scale.

#### Creating Terraform Modules:
```hcl
# modules/vpc/main.tf
variable "cidr_block" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
    Type = "public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
    Type = "private"
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  count = length(var.public_subnets)
  domain = "vpc"

  tags = {
    Name = "nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count = length(var.public_subnets)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "nat-gateway-${count.index + 1}"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table" "private" {
  count = length(var.private_subnets)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "private-rt-${count.index + 1}"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
```

#### Module Outputs:
```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}
```

#### Using Modules in Main Configuration:
```hcl
# main.tf
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# Use VPC module
module "vpc" {
  source = "./modules/vpc"

  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.11.0/24", "10.0.12.0/24"]
}

# EKS Cluster using the VPC
module "eks" {
  source = "./modules/eks"

  cluster_name = "my-cluster"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids

  node_groups = {
    main = {
      desired_capacity = 2
      max_capacity     = 5
      min_capacity     = 1
      instance_types   = ["t3.medium"]
    }
  }
}
```

#### Remote State Management:
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# Create S3 bucket for state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-bucket"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

#### Infrastructure Monitoring Setup:
```hcl
# monitoring.tf
# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "Infrastructure-Dashboard"

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
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.web.id],
            [".", "NetworkIn", ".", "."],
            [".", "NetworkOut", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "EC2 Instance Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            [".", "TargetResponseTime", ".", "."]
          ]
          view   = "timeSeries"
          region = "us-east-1"
          title  = "Load Balancer Metrics"
        }
      }
    ]
  })
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "infrastructure-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.web.id
  }
}

resource "aws_cloudwatch_metric_alarm" "elb_response_time" {
  alarm_name          = "high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ALB response time"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}
```

#### Terraform Workspace Management:
```bash
# Create and manage workspaces for different environments
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# List workspaces
terraform workspace list

# Switch workspace
terraform workspace select prod

# Use workspace in configuration
locals {
  environment = terraform.workspace
  
  instance_counts = {
    dev     = 1
    staging = 2
    prod    = 3
  }
}

resource "aws_instance" "web" {
  count = local.instance_counts[local.environment]
  # ... rest of configuration
}
```

#### Infrastructure Testing:
```bash
#!/bin/bash
# test-infrastructure.sh

# Test VPC connectivity
echo "Testing VPC connectivity..."
aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)

# Test instance health
echo "Testing instance health..."
INSTANCE_ID=$(terraform output -raw instance_id)
aws ec2 describe-instance-status --instance-ids $INSTANCE_ID

# Test load balancer
echo "Testing load balancer..."
LB_DNS=$(terraform output -raw load_balancer_dns)
curl -f http://$LB_DNS/health || echo "Health check failed"

# Test database connectivity
echo "Testing database connectivity..."
DB_ENDPOINT=$(terraform output -raw db_endpoint)
nc -zv $DB_ENDPOINT 3306

echo "Infrastructure tests completed"
```

#### Automated Infrastructure Deployment:
```yaml
# .github/workflows/infrastructure.yml
name: Infrastructure Deployment

on:
  push:
    paths:
      - 'terraform/**'
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.6.0
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Terraform Init
      run: terraform init
      working-directory: ./terraform
    
    - name: Terraform Validate
      run: terraform validate
      working-directory: ./terraform
    
    - name: Terraform Plan
      run: terraform plan -out=tfplan
      working-directory: ./terraform
    
    - name: Terraform Apply
      if: github.ref == 'refs/heads/main'
      run: terraform apply tfplan
      working-directory: ./terraform
    
    - name: Test Infrastructure
      run: ./test-infrastructure.sh
      working-directory: ./terraform
```

**Tasks:**
- [ ] Create VPC module with the code above
- [ ] Set up remote state with S3 and DynamoDB
- [ ] Deploy EKS cluster using modules
- [ ] Configure CloudWatch monitoring and alerts

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
