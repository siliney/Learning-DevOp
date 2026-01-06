# Week 1: Cloud Foundations

## Learning Objectives
- Understand cloud computing models (IaaS, PaaS, SaaS)
- Master Linux command line basics
- Set up development environment
- Learn Git version control

## Daily Tasks

### Day 1: Cloud Computing Basics

#### What is Cloud Computing?
Cloud computing delivers computing services (servers, storage, databases, networking, software) over the internet ("the cloud"). Instead of owning physical hardware, you rent access to technology services from cloud providers like AWS.

#### Key Cloud Models:
1. **IaaS (Infrastructure as a Service)**: Virtual machines, storage, networks
   - Example: AWS EC2, S3
   - You manage: OS, applications, data
   - Provider manages: Physical hardware, virtualization

2. **PaaS (Platform as a Service)**: Development platforms
   - Example: AWS Elastic Beanstalk, Heroku
   - You manage: Applications, data
   - Provider manages: Runtime, OS, infrastructure

3. **SaaS (Software as a Service)**: Ready-to-use applications
   - Example: Gmail, Salesforce, Office 365
   - You manage: Data, user access
   - Provider manages: Everything else

#### AWS Core Concepts:
- **Regions**: Geographic areas with multiple data centers
- **Availability Zones**: Isolated data centers within a region
- **Services**: 200+ services for compute, storage, networking, etc.

#### Hands-on Tutorial:
```bash
# 1. Create AWS Free Tier Account
# Go to aws.amazon.com and sign up
# Verify email and add payment method (won't be charged for free tier)

# 2. Access AWS Console
# Login at console.aws.amazon.com
# Explore the main dashboard

# 3. Launch Your First EC2 Instance
# Navigate to EC2 service
# Click "Launch Instance"
# Choose Amazon Linux 2 AMI (free tier eligible)
# Select t2.micro instance type
# Configure security group to allow SSH (port 22)
# Create and download key pair
# Launch instance
```

**Tasks:**
- [ ] Create AWS Free Tier account
- [ ] Launch first EC2 instance
- [ ] Connect to instance via SSH
- [ ] Explore AWS Console services

## 🔧 Troubleshooting Guide

### Common Issues & Solutions

#### AWS Account Setup
**Problem**: Credit card verification fails
**Solution**: 
- Use a valid credit card (debit cards may not work)
- Ensure billing address matches card details
- Contact AWS support if issues persist

**Problem**: Can't access EC2 instance via SSH
**Solution**:
```bash
# Check security group allows SSH (port 22)
# Verify key pair permissions
chmod 400 your-key.pem

# Connect with correct username
ssh -i your-key.pem ec2-user@your-instance-ip  # Amazon Linux
ssh -i your-key.pem ubuntu@your-instance-ip    # Ubuntu
```

#### Linux Commands
**Problem**: Permission denied errors
**Solution**:
```bash
# Use sudo for administrative tasks
sudo command

# Check file permissions
ls -la filename

# Fix permissions
chmod 755 script.sh  # Make executable
```

**Problem**: Command not found
**Solution**:
```bash
# Check if command exists
which command-name

# Install missing packages (Ubuntu/Debian)
sudo apt update && sudo apt install package-name

# Install missing packages (Amazon Linux/CentOS)
sudo yum install package-name
```

## 📚 Additional Resources for Week 1

### Essential Reading
- **AWS Free Tier Guide**: https://aws.amazon.com/free/
- **Linux Command Line Basics**: https://linuxcommand.org/
- **Git Tutorial**: https://git-scm.com/docs/gittutorial
- **Networking Fundamentals**: https://www.cloudflare.com/learning/

### Video Tutorials
- **AWS Console Walkthrough**: AWS Training YouTube channel
- **Linux for Beginners**: TechWorld with Nana
- **Git and GitHub Tutorial**: freeCodeCamp
- **Networking Basics**: NetworkChuck

### Practice Labs
- **AWS Free Tier Labs**: https://aws.amazon.com/getting-started/
- **Linux Practice**: OverTheWire Bandit
- **Git Practice**: https://learngitbranching.js.org/
- **Networking Labs**: Packet Tracer (Cisco)

### Day 2: Linux Command Line Mastery

#### Why Linux for DevOps?
Linux powers most cloud servers and containers. Mastering the command line is essential for automation, troubleshooting, and system administration.

#### Essential Commands Tutorial:

**File System Navigation:**
```bash
# Print current directory
pwd

# List files and directories
ls -la          # Long format with hidden files
ls -lh          # Human readable file sizes

# Change directories
cd /home/user   # Absolute path
cd ../          # Go up one level
cd ~            # Go to home directory

# Create directories
mkdir project
mkdir -p project/src/main    # Create nested directories
```

**File Operations:**
```bash
# Create files
touch file.txt              # Create empty file
echo "Hello" > file.txt     # Create file with content
echo "World" >> file.txt    # Append to file

# Copy and move files
cp file.txt backup.txt      # Copy file
cp -r folder/ backup/       # Copy directory recursively
mv file.txt newname.txt     # Rename/move file

# View file contents
cat file.txt               # Display entire file
less file.txt              # View file page by page
head -10 file.txt          # First 10 lines
tail -10 file.txt          # Last 10 lines
tail -f /var/log/syslog    # Follow log file in real-time
```

**File Permissions:**
```bash
# Understanding permissions: rwx rwx rwx (owner group others)
# r=read(4), w=write(2), x=execute(1)

# Change permissions
chmod 755 script.sh        # rwxr-xr-x (owner: all, group/others: read+execute)
chmod +x script.sh         # Add execute permission
chmod -w file.txt          # Remove write permission

# Change ownership
sudo chown user:group file.txt
sudo chown -R user:group directory/
```

**Text Processing:**
```bash
# Search in files
grep "error" /var/log/syslog           # Find lines containing "error"
grep -r "TODO" /project/src/           # Recursive search
grep -i "error" file.txt               # Case insensitive

# Text manipulation
sed 's/old/new/g' file.txt             # Replace all occurrences
awk '{print $1}' file.txt              # Print first column
sort file.txt                          # Sort lines
uniq file.txt                          # Remove duplicates
wc -l file.txt                         # Count lines
```

**Process Management:**
```bash
# View running processes
ps aux                     # All processes
ps aux | grep nginx        # Find specific process
top                        # Real-time process monitor
htop                       # Better process monitor (if installed)

# Manage processes
kill 1234                  # Kill process by PID
killall nginx              # Kill all nginx processes
nohup command &            # Run command in background
jobs                       # List background jobs
```

#### Practical Exercise:
```bash
# Create a project structure
mkdir -p ~/devops-project/{scripts,configs,logs}
cd ~/devops-project

# Create a simple monitoring script
cat > scripts/monitor.sh << 'EOF'
#!/bin/bash
echo "=== System Monitor ===" > logs/system.log
echo "Date: $(date)" >> logs/system.log
echo "Uptime: $(uptime)" >> logs/system.log
echo "Disk Usage:" >> logs/system.log
df -h >> logs/system.log
echo "Memory Usage:" >> logs/system.log
free -h >> logs/system.log
EOF

# Make script executable and run it
chmod +x scripts/monitor.sh
./scripts/monitor.sh

# View the results
cat logs/system.log
```

**Tasks:**
- [ ] Practice all file operations commands
- [ ] Create the monitoring script above
- [ ] Set up proper file permissions
- [ ] Use grep to search through system logs

### Day 3: Git & Version Control Mastery

#### Why Git for DevOps?
Git is essential for tracking code changes, collaborating with teams, and managing infrastructure as code. Every DevOps workflow relies on version control.

#### Git Fundamentals Tutorial:

**Initial Setup:**
```bash
# Install Git (if not already installed)
sudo apt update && sudo apt install git -y    # Ubuntu/Debian
# or
brew install git                               # macOS

# Configure Git globally
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --global init.defaultBranch main

# Verify configuration
git config --list
```

**Repository Basics:**
```bash
# Create a new repository
mkdir my-devops-project
cd my-devops-project
git init

# Check repository status
git status

# Create and add files
echo "# My DevOps Project" > README.md
echo "node_modules/" > .gitignore
git add README.md .gitignore

# Make your first commit
git commit -m "Initial commit: Add README and gitignore"

# View commit history
git log --oneline
```

**Working with Changes:**
```bash
# Make changes to files
echo "## Getting Started" >> README.md
echo "This project demonstrates DevOps practices." >> README.md

# See what changed
git diff
git status

# Stage and commit changes
git add README.md
git commit -m "Add getting started section to README"

# View detailed history
git log --graph --pretty=format:'%h -%d %s (%cr) <%an>'
```

**Branching Strategy:**
```bash
# Create and switch to new branch
git checkout -b feature/add-documentation
# or newer syntax:
git switch -c feature/add-documentation

# Make changes on the branch
mkdir docs
echo "# Documentation" > docs/setup.md
git add docs/setup.md
git commit -m "Add setup documentation"

# Switch back to main branch
git checkout main

# Merge the feature branch
git merge feature/add-documentation

# Delete the feature branch
git branch -d feature/add-documentation

# List all branches
git branch -a
```

**Remote Repositories (GitHub):**
```bash
# Add remote repository
git remote add origin https://github.com/username/my-devops-project.git

# Push to remote
git push -u origin main

# Clone existing repository
git clone https://github.com/username/existing-repo.git

# Fetch and pull changes
git fetch origin
git pull origin main

# Push changes
git push origin main
```

**Advanced Git Operations:**
```bash
# Undo changes (before commit)
git checkout -- filename.txt        # Discard changes to file
git reset HEAD filename.txt          # Unstage file

# Undo commits
git reset --soft HEAD~1              # Undo last commit, keep changes staged
git reset --hard HEAD~1              # Undo last commit, discard changes

# View file history
git log --follow filename.txt

# Create and apply patches
git format-patch -1 HEAD             # Create patch from last commit
git apply patch-file.patch           # Apply patch

# Stash changes temporarily
git stash                            # Save current changes
git stash pop                        # Restore stashed changes
git stash list                       # List all stashes
```

#### DevOps Git Workflow:
```bash
# 1. Feature Branch Workflow
git checkout main
git pull origin main
git checkout -b feature/new-feature

# 2. Make changes and commit
# ... make changes ...
git add .
git commit -m "Implement new feature"

# 3. Push and create pull request
git push origin feature/new-feature
# Create PR on GitHub

# 4. After PR approval, merge and cleanup
git checkout main
git pull origin main
git branch -d feature/new-feature
```

#### Practical Exercise - DevOps Repository:
```bash
# Create a DevOps project structure
mkdir devops-infrastructure
cd devops-infrastructure
git init

# Create project structure
mkdir -p {terraform,docker,kubernetes,scripts}
echo "# DevOps Infrastructure" > README.md
echo "terraform/.terraform*" > .gitignore
echo "*.tfstate*" >> .gitignore
echo ".env" >> .gitignore

# Create sample files
cat > terraform/main.tf << 'EOF'
provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}
EOF

cat > docker/Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
EOF

# Initial commit
git add .
git commit -m "Initial DevOps project structure"

# Create feature branch for web app
git checkout -b feature/web-application
echo "<h1>Hello DevOps!</h1>" > docker/index.html
git add docker/index.html
git commit -m "Add simple web application"

# Merge back to main
git checkout main
git merge feature/web-application
git branch -d feature/web-application

# View the project
git log --oneline --graph
```

**Tasks:**
- [ ] Set up Git configuration
- [ ] Create the DevOps project above
- [ ] Practice branching and merging
- [ ] Connect to GitHub and push repository

### Day 4: Networking Fundamentals for DevOps

#### Why Networking Matters in DevOps?
Understanding networking is crucial for designing secure, scalable cloud architectures, troubleshooting connectivity issues, and implementing proper security controls.

#### OSI Model & TCP/IP Tutorial:

**OSI Model Layers:**
```
7. Application  - HTTP, HTTPS, SSH, FTP
6. Presentation - SSL/TLS encryption
5. Session      - Session management
4. Transport    - TCP, UDP (ports)
3. Network      - IP addresses, routing
2. Data Link    - MAC addresses, switches
1. Physical     - Cables, wireless signals
```

**TCP/IP in Practice:**
```bash
# View network interfaces
ip addr show                    # Modern Linux
ifconfig                       # Traditional command

# View routing table
ip route show
route -n

# Test connectivity
ping google.com                # Test basic connectivity
ping -c 4 8.8.8.8             # Ping 4 times to Google DNS

# Trace network path
traceroute google.com          # See route to destination
mtr google.com                 # Real-time traceroute

# Check open ports
netstat -tuln                  # Show listening ports
ss -tuln                       # Modern alternative to netstat
```

#### DNS Deep Dive:
```bash
# DNS lookup tools
nslookup google.com            # Basic DNS lookup
dig google.com                 # Detailed DNS information
dig @8.8.8.8 google.com        # Query specific DNS server

# DNS record types
dig google.com A               # IPv4 address
dig google.com AAAA            # IPv6 address
dig google.com MX              # Mail exchange records
dig google.com TXT             # Text records
dig google.com NS              # Name servers

# Reverse DNS lookup
dig -x 8.8.8.8                # Find hostname for IP
```

#### Network Troubleshooting:
```bash
# Check if service is running
sudo systemctl status nginx
sudo systemctl status ssh

# Test specific ports
telnet google.com 80           # Test HTTP port
nc -zv google.com 80           # Test port with netcat

# Monitor network traffic
sudo tcpdump -i eth0           # Capture packets on interface
sudo tcpdump port 80           # Capture HTTP traffic
sudo tcpdump host 8.8.8.8      # Capture traffic to/from specific host

# Check network statistics
iftop                          # Real-time bandwidth usage
nethogs                        # Network usage by process
```

#### Subnetting & CIDR Tutorial:

**Understanding CIDR Notation:**
```
192.168.1.0/24 means:
- Network: 192.168.1.0
- Subnet mask: 255.255.255.0 (/24 = 24 bits for network)
- Host range: 192.168.1.1 - 192.168.1.254
- Broadcast: 192.168.1.255
- Total hosts: 254 (256 - 2 for network and broadcast)
```

**Common Subnet Sizes:**
```
/8  = 255.0.0.0     = 16,777,214 hosts (Class A)
/16 = 255.255.0.0   = 65,534 hosts (Class B)
/24 = 255.255.255.0 = 254 hosts (Class C)
/28 = 255.255.255.240 = 14 hosts
/30 = 255.255.255.252 = 2 hosts (point-to-point links)
```

**Subnet Calculator:**
```bash
# Install ipcalc for subnet calculations
sudo apt install ipcalc -y

# Calculate subnet information
ipcalc 192.168.1.0/24
ipcalc 10.0.0.0/16
ipcalc 172.16.0.0/12
```

#### AWS Networking Concepts:

**VPC (Virtual Private Cloud):**
```
VPC = Your own isolated network in AWS cloud
- Choose IP range (e.g., 10.0.0.0/16)
- Spans multiple Availability Zones
- Default VPC provided automatically
```

**Subnets:**
```
Public Subnet:  Has route to Internet Gateway
Private Subnet: No direct internet access
Database Subnet: Isolated for databases
```

**Security Groups vs NACLs:**
```
Security Groups (Instance Level):
- Stateful (return traffic automatically allowed)
- Allow rules only
- Applied to instances

Network ACLs (Subnet Level):
- Stateless (must allow return traffic)
- Allow and deny rules
- Applied to subnets
```

#### Practical Network Lab:
```bash
# 1. Network Discovery
# Find your current network configuration
ip addr show
ip route show
cat /etc/resolv.conf            # DNS servers

# 2. Test connectivity to different services
ping -c 3 google.com            # Internet connectivity
ping -c 3 8.8.8.8              # DNS server
ping -c 3 $(ip route | grep default | awk '{print $3}')  # Default gateway

# 3. Port scanning (ethical - your own systems only)
nmap -sT localhost              # Scan your own machine
nmap -sT 192.168.1.1           # Scan your router

# 4. Create a simple web server and test connectivity
python3 -m http.server 8080 &  # Start web server
curl http://localhost:8080     # Test local connection
netstat -tuln | grep 8080     # Verify port is listening
kill %1                        # Stop the web server

# 5. DNS testing
dig +short google.com          # Quick IP lookup
dig +trace google.com          # Full DNS resolution path
```

#### Network Security Basics:
```bash
# Firewall management (Ubuntu/Debian)
sudo ufw status                # Check firewall status
sudo ufw enable                # Enable firewall
sudo ufw allow ssh             # Allow SSH
sudo ufw allow 80/tcp          # Allow HTTP
sudo ufw allow from 192.168.1.0/24  # Allow from specific subnet
sudo ufw deny 23               # Block telnet

# View firewall rules
sudo ufw status numbered
sudo iptables -L               # View raw iptables rules
```

**Tasks:**
- [ ] Complete the network discovery lab above
- [ ] Practice DNS lookups with dig
- [ ] Calculate subnets using ipcalc
- [ ] Set up basic firewall rules
- [ ] Understand VPC concepts for AWS

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
