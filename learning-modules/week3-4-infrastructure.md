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
