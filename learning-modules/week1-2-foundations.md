# Week 1-2: Cloud Foundations

## Learning Objectives
- Understand cloud computing models (IaaS, PaaS, SaaS)
- Master Linux command line basics
- Set up development environment
- Learn Git version control

## Daily Tasks

### Day 1: Cloud Computing Basics
- [ ] Read AWS Cloud Practitioner Guide (Chapters 1-3)
- [ ] Watch: "What is Cloud Computing?" videos
- [ ] Create AWS Free Tier account
- [ ] Complete: AWS Cloud Practitioner Essentials (Module 1)

### Day 2: Linux Command Line
- [ ] Install WSL2 or Linux VM
- [ ] Practice basic commands: ls, cd, mkdir, rm, cp, mv
- [ ] Learn file permissions: chmod, chown
- [ ] Practice text manipulation: grep, sed, awk

### Day 3: Git & Version Control
- [ ] Install Git and configure
- [ ] Create GitHub account
- [ ] Practice: git init, add, commit, push, pull
- [ ] Learn branching: git branch, checkout, merge

### Day 4: Networking Fundamentals
- [ ] Understand OSI model
- [ ] Learn TCP/IP basics
- [ ] Practice: ping, traceroute, netstat
- [ ] Study DNS and DHCP

### Day 5: AWS Core Services
- [ ] Explore AWS Console
- [ ] Learn EC2 basics
- [ ] Understand VPC concepts
- [ ] Practice launching EC2 instance

## Hands-on Lab: Launch Your First EC2 Instance

```bash
# Connect to EC2 instance
ssh -i your-key.pem ec2-user@your-instance-ip

# Update system
sudo yum update -y

# Install Docker
sudo yum install docker -y
sudo systemctl start docker
sudo usermod -a -G docker ec2-user

# Test Docker
docker run hello-world
```

## Assessment
- [ ] Deploy a simple web server on EC2
- [ ] Set up Git repository with proper branching
- [ ] Configure basic VPC with public/private subnets
- [ ] Document your learning in README.md

## Resources
- [AWS Free Tier](https://aws.amazon.com/free/)
- [Linux Command Line Tutorial](https://linuxcommand.org/)
- [Git Tutorial](https://git-scm.com/docs/gittutorial)
- [Networking Basics](https://www.cloudflare.com/learning/network-layer/)
