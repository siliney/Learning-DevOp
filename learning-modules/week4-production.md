# Week 4: Production, Monitoring & Security

## Learning Objectives
- Implement comprehensive monitoring
- Apply security best practices
- Optimize costs and performance
- Handle production incidents

## Daily Tasks

### Day 1: Advanced Monitoring with CloudWatch

#### Why Monitoring Matters in DevOps?
Monitoring provides visibility into system health, performance, and user experience. Without proper monitoring, you're flying blind in production.

#### CloudWatch Core Components:
- **Metrics**: Numerical data points over time (CPU, memory, custom metrics)
- **Logs**: Text-based log data from applications and services
- **Alarms**: Notifications based on metric thresholds
- **Dashboards**: Visual representation of metrics and logs

#### Setting Up CloudWatch with Terraform:
```hcl
# cloudwatch.tf
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/myapp"
  retention_in_days = 14

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}

# Custom metric alarm
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

# SNS topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "cloudwatch-alerts"
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "admin@example.com"
}
```

#### CloudWatch Agent Configuration:
```json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/aws/ec2/nginx/access",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/aws/ec2/nginx/error",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "MyApp/EC2",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
```

#### Installing CloudWatch Agent:
```bash
# Download and install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
sudo rpm -U ./amazon-cloudwatch-agent.rpm

# Configure the agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard

# Start the agent
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent
```

#### Custom Metrics with AWS CLI:
```bash
# Send custom metric
aws cloudwatch put-metric-data \
    --namespace "MyApp/Business" \
    --metric-data MetricName=OrdersProcessed,Value=42,Unit=Count

# Send metric with dimensions
aws cloudwatch put-metric-data \
    --namespace "MyApp/Performance" \
    --metric-data MetricName=ResponseTime,Value=250,Unit=Milliseconds,Dimensions=Environment=prod,Service=api
```

#### Application-Level Monitoring:
```javascript
// Node.js application with custom metrics
const AWS = require('aws-sdk');
const cloudwatch = new AWS.CloudWatch();

class MetricsCollector {
    async sendMetric(metricName, value, unit = 'Count', dimensions = []) {
        const params = {
            Namespace: 'MyApp/Application',
            MetricData: [{
                MetricName: metricName,
                Value: value,
                Unit: unit,
                Dimensions: dimensions,
                Timestamp: new Date()
            }]
        };
        
        try {
            await cloudwatch.putMetricData(params).promise();
        } catch (error) {
            console.error('Failed to send metric:', error);
        }
    }
    
    async recordResponseTime(endpoint, responseTime) {
        await this.sendMetric('ResponseTime', responseTime, 'Milliseconds', [
            { Name: 'Endpoint', Value: endpoint }
        ]);
    }
    
    async recordError(errorType) {
        await this.sendMetric('Errors', 1, 'Count', [
            { Name: 'ErrorType', Value: errorType }
        ]);
    }
}

// Usage in Express middleware
const metrics = new MetricsCollector();

app.use((req, res, next) => {
    const start = Date.now();
    
    res.on('finish', () => {
        const responseTime = Date.now() - start;
        metrics.recordResponseTime(req.path, responseTime);
        
        if (res.statusCode >= 400) {
            metrics.recordError(`HTTP_${res.statusCode}`);
        }
    });
    
    next();
});
```

#### CloudWatch Insights Queries:
```sql
-- Find errors in application logs
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100

-- Analyze response times
fields @timestamp, @message
| filter @message like /response_time/
| parse @message "response_time: * ms" as response_time
| stats avg(response_time), max(response_time), min(response_time) by bin(5m)

-- Top error messages
fields @timestamp, @message
| filter level = "ERROR"
| stats count() as error_count by @message
| sort error_count desc
| limit 10
```

#### Distributed Tracing with X-Ray:
```javascript
// Enable X-Ray tracing in Node.js
const AWSXRay = require('aws-xray-sdk-core');
const AWS = AWSXRay.captureAWS(require('aws-sdk'));

// Capture HTTP requests
const captureHTTPs = require('aws-xray-sdk-httpc');
captureHTTPs(require('https'));

// Express middleware
app.use(AWSXRay.express.openSegment('MyApp'));

app.get('/api/users', async (req, res) => {
    const segment = AWSXRay.getSegment();
    
    try {
        // Create subsegment for database call
        const subsegment = segment.addNewSubsegment('database-query');
        subsegment.addAnnotation('query', 'SELECT * FROM users');
        
        const users = await getUsersFromDatabase();
        
        subsegment.close();
        
        res.json(users);
    } catch (error) {
        segment.addError(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.use(AWSXRay.express.closeSegment());
```

**Tasks:**
- [ ] Set up CloudWatch agent on EC2 instance
- [ ] Create custom metrics and alarms
- [ ] Implement application-level monitoring
- [ ] Practice CloudWatch Insights queries

### Day 2: Security Implementation & Best Practices

#### AWS Security Best Practices:
Security is not an afterthought in DevOps - it must be built into every layer of your infrastructure and applications.

#### IAM Security with Terraform:
```hcl
# iam-security.tf
# Principle of least privilege - specific permissions only
resource "aws_iam_policy" "app_policy" {
  name        = "app-specific-policy"
  description = "Minimal permissions for application"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::my-app-bucket/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/my-function:*"
      }
    ]
  })
}

# Service role with minimal permissions
resource "aws_iam_role" "app_role" {
  name = "app-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_policy_attachment" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}

# Enable CloudTrail for audit logging
resource "aws_cloudtrail" "main" {
  name           = "main-cloudtrail"
  s3_bucket_name = aws_s3_bucket.cloudtrail.bucket

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::my-sensitive-bucket/*"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}
```

#### Secrets Management with AWS Secrets Manager:
```hcl
# secrets.tf
resource "aws_secretsmanager_secret" "db_password" {
  name        = "prod/myapp/db-password"
  description = "Database password for production"
  
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password.result
  })
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Lambda function to rotate secrets
resource "aws_lambda_function" "rotate_secret" {
  filename         = "rotate_secret.zip"
  function_name    = "rotate-db-secret"
  role            = aws_iam_role.lambda_rotation.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  
  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${var.aws_region}.amazonaws.com"
    }
  }
}
```

#### Network Security Configuration:
```hcl
# network-security.tf
# Security group with minimal access
resource "aws_security_group" "web_sg" {
  name_prefix = "web-sg"
  vpc_id      = aws_vpc.main.id

  # Only allow HTTPS from specific sources
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # Internal traffic only
  }

  # Allow HTTP from ALB only
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTPS outbound only
  }

  tags = {
    Name = "web-security-group"
  }
}

# Network ACL for additional layer of security
resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.main.id

  # Allow inbound from VPC only
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = aws_vpc.main.cidr_block
    from_port  = 80
    to_port    = 80
  }

  # Deny all other inbound traffic
  ingress {
    protocol   = "-1"
    rule_no    = 200
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "private-nacl"
  }
}
```

#### Container Security Scanning:
```dockerfile
# Secure Dockerfile practices
FROM node:18-alpine AS base

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Install security updates
RUN apk update && apk upgrade && apk add --no-cache dumb-init

# Set working directory
WORKDIR /app

# Copy package files first (better caching)
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy application code
COPY --chown=nextjs:nodejs . .

# Remove unnecessary packages
RUN apk del apk-tools

# Use non-root user
USER nextjs

# Use dumb-init for proper signal handling
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

#### Security Scanning in CI/CD:
```yaml
# .github/workflows/security-scan.yml
name: Security Scanning

on: [push, pull_request]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    # Dependency vulnerability scanning
    - name: Run npm audit
      run: npm audit --audit-level high
    
    # SAST (Static Application Security Testing)
    - name: Run Semgrep
      uses: returntocorp/semgrep-action@v1
      with:
        config: >-
          p/security-audit
          p/secrets
          p/owasp-top-ten
    
    # Container image scanning
    - name: Build Docker image
      run: docker build -t myapp:${{ github.sha }} .
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'myapp:${{ github.sha }}'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
    
    # Infrastructure scanning
    - name: Run Checkov
      uses: bridgecrewio/checkov-action@master
      with:
        directory: .
        framework: terraform
        output_format: sarif
        output_file_path: checkov-results.sarif
    
    - name: Upload Checkov scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: checkov-results.sarif
```

#### Runtime Security Monitoring:
```bash
# Install and configure Falco for runtime security
curl -s https://falco.org/repo/falcosecurity-3672BA8F.asc | apt-key add -
echo "deb https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
apt-get install -y falco

# Custom Falco rules
cat > /etc/falco/falco_rules.local.yaml << 'EOF'
- rule: Detect crypto miners
  desc: Detect cryptocurrency miners
  condition: spawned_process and proc.name in (xmrig, minergate)
  output: Crypto miner detected (user=%user.name command=%proc.cmdline)
  priority: CRITICAL

- rule: Unexpected network connection
  desc: Detect unexpected outbound connections
  condition: outbound and not proc.name in (curl, wget, apt, yum)
  output: Unexpected network connection (user=%user.name command=%proc.cmdline connection=%fd.name)
  priority: WARNING
EOF

# Start Falco
systemctl enable falco
systemctl start falco
```

#### Application Security Headers:
```javascript
// Express.js security middleware
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP'
});

app.use('/api/', limiter);

// Input validation middleware
const { body, validationResult } = require('express-validator');

app.post('/api/users',
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 8 }).matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/),
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    // Process request
  }
);
```

**Tasks:**
- [ ] Implement IAM policies with least privilege
- [ ] Set up secrets management with rotation
- [ ] Configure security scanning in CI/CD
- [ ] Apply security headers to web applications

### Day 3: Cost Optimization & Performance

#### AWS Cost Management Strategy:
Cost optimization is crucial for sustainable cloud operations. Understanding and controlling costs prevents budget overruns and improves ROI.

#### Cost Monitoring with Terraform:
```hcl
# cost-management.tf
resource "aws_budgets_budget" "monthly_budget" {
  name         = "monthly-budget"
  budget_type  = "COST"
  limit_amount = "100"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  cost_filters = {
    Service = ["Amazon Elastic Compute Cloud - Compute"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = ["admin@example.com"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["admin@example.com"]
  }
}

# Cost anomaly detection
resource "aws_ce_anomaly_detector" "service_monitor" {
  name         = "service-spend-monitor"
  monitor_type = "DIMENSIONAL"

  specification = jsonencode({
    Dimension = "SERVICE"
    MatchOptions = ["EQUALS"]
    Values = ["EC2-Instance", "Amazon Simple Storage Service"]
  })
}

resource "aws_ce_anomaly_subscription" "anomaly_alerts" {
  name      = "anomaly-alerts"
  frequency = "DAILY"
  
  monitor_arn_list = [
    aws_ce_anomaly_detector.service_monitor.arn
  ]
  
  subscriber {
    type    = "EMAIL"
    address = "admin@example.com"
  }
  
  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = ["100"]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }
}
```

#### Auto Scaling for Cost Optimization:
```hcl
# autoscaling.tf
resource "aws_launch_template" "web" {
  name_prefix   = "web-template"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  vpc_security_group_ids = [aws_security_group.web.id]
  
  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    app_version = var.app_version
  }))
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-server"
      Environment = var.environment
    }
  }
}

resource "aws_autoscaling_group" "web" {
  name                = "web-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"
  
  min_size         = 1
  max_size         = 10
  desired_capacity = 2
  
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
  
  # Scale based on CPU utilization
  tag {
    key                 = "Name"
    value               = "web-asg-instance"
    propagate_at_launch = true
  }
}

# CPU-based scaling policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

# CloudWatch alarms for scaling
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "cpu-utilization-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}
```

#### Spot Instances for Cost Savings:
```hcl
# spot-instances.tf
resource "aws_launch_template" "spot" {
  name_prefix   = "spot-template"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.medium"
  
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = "0.05"  # Maximum price per hour
    }
  }
  
  vpc_security_group_ids = [aws_security_group.web.id]
}

resource "aws_autoscaling_group" "spot" {
  name                = "spot-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  
  min_size         = 0
  max_size         = 5
  desired_capacity = 2
  
  # Mixed instances policy for cost optimization
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.spot.id
        version           = "$Latest"
      }
      
      override {
        instance_type = "t3.medium"
      }
      override {
        instance_type = "t3.large"
      }
    }
    
    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 25
      spot_allocation_strategy                 = "diversified"
    }
  }
}
```

#### Cost Analysis Scripts:
```bash
#!/bin/bash
# cost-analysis.sh

# Get monthly costs by service
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-02-01 \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --output table

# Get daily costs for current month
START_DATE=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
END_DATE=$(date +%Y-%m-%d)

aws ce get-cost-and-usage \
    --time-period Start=$START_DATE,End=$END_DATE \
    --granularity DAILY \
    --metrics BlendedCost \
    --output table

# Get rightsizing recommendations
aws ce get-rightsizing-recommendation \
    --service EC2-Instance \
    --output table

# Get reserved instance recommendations
aws ce get-reservation-purchase-recommendation \
    --service EC2-Instance \
    --output table
```

#### Resource Optimization:
```python
# resource-optimizer.py
import boto3
import json
from datetime import datetime, timedelta

class ResourceOptimizer:
    def __init__(self):
        self.ec2 = boto3.client('ec2')
        self.cloudwatch = boto3.client('cloudwatch')
        
    def find_underutilized_instances(self):
        """Find EC2 instances with low CPU utilization"""
        instances = self.ec2.describe_instances()
        underutilized = []
        
        for reservation in instances['Reservations']:
            for instance in reservation['Instances']:
                if instance['State']['Name'] == 'running':
                    instance_id = instance['InstanceId']
                    
                    # Get CPU utilization for last 7 days
                    end_time = datetime.utcnow()
                    start_time = end_time - timedelta(days=7)
                    
                    response = self.cloudwatch.get_metric_statistics(
                        Namespace='AWS/EC2',
                        MetricName='CPUUtilization',
                        Dimensions=[
                            {'Name': 'InstanceId', 'Value': instance_id}
                        ],
                        StartTime=start_time,
                        EndTime=end_time,
                        Period=3600,
                        Statistics=['Average']
                    )
                    
                    if response['Datapoints']:
                        avg_cpu = sum(dp['Average'] for dp in response['Datapoints']) / len(response['Datapoints'])
                        
                        if avg_cpu < 10:  # Less than 10% CPU utilization
                            underutilized.append({
                                'InstanceId': instance_id,
                                'InstanceType': instance['InstanceType'],
                                'AvgCPU': avg_cpu
                            })
        
        return underutilized
    
    def find_unattached_volumes(self):
        """Find EBS volumes not attached to instances"""
        volumes = self.ec2.describe_volumes()
        unattached = []
        
        for volume in volumes['Volumes']:
            if volume['State'] == 'available':
                unattached.append({
                    'VolumeId': volume['VolumeId'],
                    'Size': volume['Size'],
                    'VolumeType': volume['VolumeType']
                })
        
        return unattached
    
    def generate_report(self):
        """Generate optimization report"""
        report = {
            'timestamp': datetime.utcnow().isoformat(),
            'underutilized_instances': self.find_underutilized_instances(),
            'unattached_volumes': self.find_unattached_volumes()
        }
        
        return json.dumps(report, indent=2)

if __name__ == "__main__":
    optimizer = ResourceOptimizer()
    print(optimizer.generate_report())
```

#### Performance Monitoring:
```javascript
// Application performance monitoring
const express = require('express');
const prometheus = require('prom-client');

// Create metrics
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const httpRequestsTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const activeConnections = new prometheus.Gauge({
  name: 'active_connections',
  help: 'Number of active connections'
});

// Middleware to collect metrics
function metricsMiddleware(req, res, next) {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode)
      .observe(duration);
    
    httpRequestsTotal
      .labels(req.method, route, res.statusCode)
      .inc();
  });
  
  next();
}

const app = express();
app.use(metricsMiddleware);

// Metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(prometheus.register.metrics());
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});
```

**Tasks:**
- [ ] Set up AWS budgets and cost alerts
- [ ] Implement auto-scaling policies
- [ ] Run the resource optimization script
- [ ] Add performance monitoring to your application

### Day 4: Disaster Recovery & High Availability

#### Disaster Recovery Planning:
DR ensures business continuity when disasters strike. AWS provides multiple strategies for different RTO (Recovery Time Objective) and RPO (Recovery Point Objective) requirements.

#### Multi-Region Architecture:
```hcl
# multi-region-dr.tf
# Primary region resources
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

# DR region resources
provider "aws" {
  alias  = "dr"
  region = "us-west-2"
}

# Primary region VPC
resource "aws_vpc" "primary" {
  provider   = aws.primary
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "primary-vpc"
  }
}

# DR region VPC
resource "aws_vpc" "dr" {
  provider   = aws.dr
  cidr_block = "10.1.0.0/16"
  
  tags = {
    Name = "dr-vpc"
  }
}

# VPC Peering for cross-region connectivity
resource "aws_vpc_peering_connection" "primary_to_dr" {
  provider    = aws.primary
  vpc_id      = aws_vpc.primary.id
  peer_vpc_id = aws_vpc.dr.id
  peer_region = "us-west-2"
  auto_accept = false
  
  tags = {
    Name = "primary-to-dr-peering"
  }
}

resource "aws_vpc_peering_connection_accepter" "dr_accept" {
  provider                  = aws.dr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_dr.id
  auto_accept               = true
  
  tags = {
    Name = "dr-accept-peering"
  }
}
```

#### RDS Multi-AZ and Cross-Region Backups:
```hcl
# rds-dr.tf
# Primary database with Multi-AZ
resource "aws_db_instance" "primary" {
  provider = aws.primary
  
  identifier     = "primary-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.medium"
  
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_type          = "gp2"
  storage_encrypted     = true
  
  db_name  = "myapp"
  username = "admin"
  password = random_password.db_password.result
  
  multi_az               = true  # Enable Multi-AZ for HA
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Enable automated backups
  copy_tags_to_snapshot = true
  skip_final_snapshot   = false
  final_snapshot_identifier = "primary-db-final-snapshot"
  
  # Enable enhanced monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  
  tags = {
    Name = "primary-database"
  }
}

# Cross-region read replica for DR
resource "aws_db_instance" "dr_replica" {
  provider = aws.dr
  
  identifier = "dr-replica"
  
  # Create read replica from primary
  replicate_source_db = aws_db_instance.primary.identifier
  
  instance_class = "db.t3.medium"
  
  # Can be promoted to standalone DB during DR
  backup_retention_period = 7
  
  tags = {
    Name = "dr-read-replica"
  }
}
```

#### S3 Cross-Region Replication:
```hcl
# s3-replication.tf
# Primary S3 bucket
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "myapp-primary-${random_string.bucket_suffix.result}"
}

# DR S3 bucket
resource "aws_s3_bucket" "dr" {
  provider = aws.dr
  bucket   = "myapp-dr-${random_string.bucket_suffix.result}"
}

# Enable versioning (required for replication)
resource "aws_s3_bucket_versioning" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.dr.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IAM role for replication
resource "aws_iam_role" "replication" {
  provider = aws.primary
  name     = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# Replication configuration
resource "aws_s3_bucket_replication_configuration" "replication" {
  provider   = aws.primary
  depends_on = [aws_s3_bucket_versioning.primary]
  
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.dr.arn
      storage_class = "STANDARD_IA"
    }
  }
}
```

#### Application Load Balancer with Health Checks:
```hcl
# alb-ha.tf
resource "aws_lb" "main" {
  provider = aws.primary
  
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = aws_subnet.public[*].id

  enable_deletion_protection = true

  tags = {
    Name = "main-alb"
  }
}

resource "aws_lb_target_group" "web" {
  provider = aws.primary
  
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.primary.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "web-target-group"
  }
}

# Route 53 health checks and failover
resource "aws_route53_health_check" "primary" {
  fqdn                            = aws_lb.main.dns_name
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/health"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = "us-east-1"
  cloudwatch_alarm_name           = "primary-health-check"
  insufficient_data_health_status = "Failure"

  tags = {
    Name = "primary-health-check"
  }
}

resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.example.com"
  type    = "A"

  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary.id

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
```

#### Backup and Recovery Automation:
```bash
#!/bin/bash
# backup-automation.sh

# Database backup
backup_database() {
    local db_identifier=$1
    local snapshot_id="manual-backup-$(date +%Y%m%d-%H%M%S)"
    
    echo "Creating database snapshot: $snapshot_id"
    aws rds create-db-snapshot \
        --db-instance-identifier $db_identifier \
        --db-snapshot-identifier $snapshot_id
    
    # Wait for snapshot to complete
    aws rds wait db-snapshot-completed \
        --db-snapshot-identifier $snapshot_id
    
    echo "Database backup completed: $snapshot_id"
}

# EBS volume backup
backup_volumes() {
    local instance_id=$1
    
    # Get all volumes attached to instance
    volumes=$(aws ec2 describe-volumes \
        --filters "Name=attachment.instance-id,Values=$instance_id" \
        --query 'Volumes[].VolumeId' \
        --output text)
    
    for volume in $volumes; do
        snapshot_id="vol-backup-$(date +%Y%m%d-%H%M%S)"
        
        echo "Creating volume snapshot: $snapshot_id for volume: $volume"
        aws ec2 create-snapshot \
            --volume-id $volume \
            --description "Automated backup of $volume" \
            --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=$snapshot_id}]"
    done
}

# S3 backup to different region
backup_s3() {
    local source_bucket=$1
    local dest_bucket=$2
    
    echo "Syncing S3 bucket $source_bucket to $dest_bucket"
    aws s3 sync s3://$source_bucket s3://$dest_bucket \
        --delete \
        --storage-class STANDARD_IA
}

# Cleanup old backups
cleanup_old_backups() {
    local retention_days=7
    local cutoff_date=$(date -d "$retention_days days ago" +%Y-%m-%d)
    
    # Delete old RDS snapshots
    aws rds describe-db-snapshots \
        --snapshot-type manual \
        --query "DBSnapshots[?SnapshotCreateTime<'$cutoff_date'].DBSnapshotIdentifier" \
        --output text | \
    while read snapshot; do
        if [ ! -z "$snapshot" ]; then
            echo "Deleting old RDS snapshot: $snapshot"
            aws rds delete-db-snapshot --db-snapshot-identifier $snapshot
        fi
    done
    
    # Delete old EBS snapshots
    aws ec2 describe-snapshots \
        --owner-ids self \
        --query "Snapshots[?StartTime<'$cutoff_date'].SnapshotId" \
        --output text | \
    while read snapshot; do
        if [ ! -z "$snapshot" ]; then
            echo "Deleting old EBS snapshot: $snapshot"
            aws ec2 delete-snapshot --snapshot-id $snapshot
        fi
    done
}

# Main backup function
main() {
    echo "Starting automated backup process..."
    
    # Backup database
    backup_database "primary-db"
    
    # Backup EBS volumes for web servers
    for instance in $(aws ec2 describe-instances \
        --filters "Name=tag:Role,Values=web-server" "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text); do
        backup_volumes $instance
    done
    
    # Backup S3 data
    backup_s3 "myapp-primary-bucket" "myapp-backup-bucket"
    
    # Cleanup old backups
    cleanup_old_backups
    
    echo "Backup process completed successfully"
}

# Run main function
main "$@"
```

#### Disaster Recovery Testing:
```python
# dr-test.py
import boto3
import time
import json
from datetime import datetime

class DRTester:
    def __init__(self):
        self.rds_primary = boto3.client('rds', region_name='us-east-1')
        self.rds_dr = boto3.client('rds', region_name='us-west-2')
        self.route53 = boto3.client('route53')
        
    def test_database_failover(self):
        """Test RDS read replica promotion"""
        print("Testing database failover...")
        
        try:
            # Promote read replica to standalone database
            response = self.rds_dr.promote_read_replica(
                DBInstanceIdentifier='dr-replica'
            )
            
            print(f"Promoting read replica: {response['DBInstance']['DBInstanceIdentifier']}")
            
            # Wait for promotion to complete
            waiter = self.rds_dr.get_waiter('db_instance_available')
            waiter.wait(DBInstanceIdentifier='dr-replica')
            
            print("Database failover test completed successfully")
            return True
            
        except Exception as e:
            print(f"Database failover test failed: {str(e)}")
            return False
    
    def test_dns_failover(self):
        """Test Route 53 DNS failover"""
        print("Testing DNS failover...")
        
        try:
            # Update health check to simulate primary failure
            # This would typically be done by stopping the primary ALB
            
            # Check DNS resolution
            import socket
            result = socket.gethostbyname('app.example.com')
            print(f"DNS resolves to: {result}")
            
            return True
            
        except Exception as e:
            print(f"DNS failover test failed: {str(e)}")
            return False
    
    def generate_dr_report(self):
        """Generate disaster recovery test report"""
        report = {
            'timestamp': datetime.utcnow().isoformat(),
            'tests': {
                'database_failover': self.test_database_failover(),
                'dns_failover': self.test_dns_failover()
            }
        }
        
        return json.dumps(report, indent=2)

if __name__ == "__main__":
    tester = DRTester()
    print(tester.generate_dr_report())
```

**Tasks:**
- [ ] Set up multi-region infrastructure
- [ ] Configure RDS Multi-AZ and cross-region replicas
- [ ] Implement automated backup scripts
- [ ] Test disaster recovery procedures

### Day 5: Production Readiness
- [ ] Implement health checks
- [ ] Set up log management
- [ ] Create runbooks and documentation
- [ ] Practice: Production deployment

## Hands-on Lab: Production-Ready System

```yaml
# monitoring-stack.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
```

### Day 5: Production Readiness & Final Assessment

#### Production Readiness Checklist:
A production-ready system must be secure, scalable, monitored, and maintainable. This final day consolidates all previous learning into a complete production deployment.

#### Complete Production Infrastructure:
```hcl
# production-infrastructure.tf
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# Production VPC with multiple AZs
module "vpc" {
  source = "./modules/vpc"
  
  cidr_block = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  
  enable_nat_gateway = true
}

# Production EKS cluster
module "eks" {
  source = "./modules/eks"
  
  cluster_name    = "production-cluster"
  cluster_version = "1.28"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  node_groups = {
    main = {
      desired_capacity = 3
      max_capacity     = 10
      min_capacity     = 3
      instance_types = ["t3.medium", "t3.large"]
    }
  }
}
```

#### Production Deployment Pipeline:
```yaml
# .github/workflows/production-deploy.yml
name: Production Deployment

on:
  push:
    tags: ['v*']

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Container Security Scan
      run: |
        docker build -t app:${{ github.sha }} .
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
          aquasec/trivy image --exit-code 1 --severity HIGH,CRITICAL app:${{ github.sha }}

  deploy-production:
    needs: security-scan
    runs-on: ubuntu-latest
    environment: production
    steps:
    - name: Deploy to EKS
      run: |
        aws eks update-kubeconfig --region us-east-1 --name production-cluster
        kubectl apply -f k8s/production/
        kubectl rollout status deployment/web-app -n production --timeout=300s
```

#### Final Production Checklist:
```markdown
## Production Readiness Checklist

### Security ✅
- [ ] All secrets stored in AWS Secrets Manager
- [ ] IAM roles follow principle of least privilege
- [ ] Security groups restrict access appropriately
- [ ] SSL/TLS certificates configured
- [ ] Container images scanned for vulnerabilities

### Monitoring ✅
- [ ] Application metrics exposed and collected
- [ ] Infrastructure monitoring with CloudWatch
- [ ] Log aggregation configured
- [ ] Alerting rules defined for critical issues
- [ ] Health checks implemented for all services

### High Availability ✅
- [ ] Multi-AZ deployment configured
- [ ] Auto-scaling policies in place
- [ ] Load balancers with health checks
- [ ] Database Multi-AZ enabled
- [ ] Cross-region backups configured

### Performance ✅
- [ ] Load testing completed
- [ ] Performance benchmarks established
- [ ] Caching strategies implemented
- [ ] Database performance optimized
```

**Final Assessment Tasks:**
- [ ] Deploy complete production infrastructure
- [ ] Implement comprehensive monitoring
- [ ] Test disaster recovery procedures
- [ ] Complete production readiness checklist
- [ ] Document operational procedures
- [ ] Present final project demonstrating mastery

## Certification Preparation
- [ ] AWS Solutions Architect Associate
- [ ] AWS DevOps Engineer Professional
- [ ] Kubernetes CKA certification
- [ ] Create professional portfolio
