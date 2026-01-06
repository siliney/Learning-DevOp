# Week 5-6: CI/CD Pipelines & Automation

## Learning Objectives
- Build automated CI/CD pipelines
- Implement testing strategies
- Master deployment automation
- Learn GitOps principles

## Daily Tasks

### Day 1: GitHub Actions Fundamentals

#### What is CI/CD?
**Continuous Integration (CI)**: Automatically build and test code changes
**Continuous Deployment (CD)**: Automatically deploy tested code to production

GitHub Actions automates workflows triggered by repository events (push, pull request, etc.).

#### GitHub Actions Core Concepts:
- **Workflow**: Automated process defined in YAML
- **Job**: Set of steps that execute on the same runner
- **Step**: Individual task (run command, use action)
- **Runner**: Server that executes workflows
- **Action**: Reusable unit of code

#### Your First GitHub Actions Workflow:
```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run linting
      run: npm run lint
    
    - name: Run tests
      run: npm test
    
    - name: Run security audit
      run: npm audit --audit-level high
```

#### Advanced Workflow with Matrix Strategy:
```yaml
# .github/workflows/matrix-test.yml
name: Matrix Testing

on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        node-version: [16, 18, 20]
        
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js ${{ matrix.node-version }}
      uses: actions/setup-node@v4
      with:
        node-version: ${{ matrix.node-version }}
    
    - name: Install and test
      run: |
        npm ci
        npm test
```

#### Environment Variables and Secrets:
```yaml
# .github/workflows/deploy.yml
name: Deploy Application

on:
  push:
    branches: [ main ]

env:
  NODE_ENV: production
  
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Deploy to S3
      run: |
        aws s3 sync ./build s3://${{ secrets.S3_BUCKET_NAME }}
        aws cloudfront create-invalidation --distribution-id ${{ secrets.CLOUDFRONT_ID }} --paths "/*"
```

#### Conditional Steps and Job Dependencies:
```yaml
name: Conditional Deployment

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    outputs:
      should-deploy: ${{ steps.check.outputs.deploy }}
    steps:
    - uses: actions/checkout@v4
    - name: Run tests
      run: npm test
    - name: Check if should deploy
      id: check
      run: |
        if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
          echo "deploy=true" >> $GITHUB_OUTPUT
        else
          echo "deploy=false" >> $GITHUB_OUTPUT
        fi

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: needs.test.outputs.should-deploy == 'true'
    steps:
    - name: Deploy application
      run: echo "Deploying to production..."
```

#### Custom Actions:
```yaml
# .github/actions/setup-app/action.yml
name: 'Setup Application'
description: 'Setup Node.js application with caching'
inputs:
  node-version:
    description: 'Node.js version'
    required: true
    default: '18'
runs:
  using: 'composite'
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'
    - name: Install dependencies
      run: npm ci
      shell: bash
```

#### Using the Custom Action:
```yaml
# .github/workflows/use-custom-action.yml
name: Use Custom Action

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Setup application
      uses: ./.github/actions/setup-app
      with:
        node-version: '18'
    - name: Build application
      run: npm run build
```

**Tasks:**
- [ ] Create the basic CI workflow above
- [ ] Add secrets to your repository settings
- [ ] Implement matrix testing strategy
- [ ] Create a custom action for your project

### Day 2: Advanced CI/CD Pipeline

#### Multi-Stage Pipeline with Quality Gates:
```yaml
# .github/workflows/advanced-pipeline.yml
name: Advanced CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # Stage 1: Code Quality
  code-quality:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run ESLint
      run: npm run lint
    
    - name: Run Prettier check
      run: npm run format:check
    
    - name: Type checking
      run: npm run type-check

  # Stage 2: Security Scanning
  security:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
    
    - name: Dependency security audit
      run: npm audit --audit-level high

  # Stage 3: Testing
  test:
    runs-on: ubuntu-latest
    needs: [code-quality, security]
    strategy:
      matrix:
        test-type: [unit, integration, e2e]
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run ${{ matrix.test-type }} tests
      run: npm run test:${{ matrix.test-type }}
    
    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      if: matrix.test-type == 'unit'
      with:
        file: ./coverage/lcov.info

  # Stage 4: Build and Push Docker Image
  build:
    runs-on: ubuntu-latest
    needs: test
    outputs:
      image-digest: ${{ steps.build.outputs.digest }}
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
    
    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
    
    - name: Build and push Docker image
      id: build
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

  # Stage 5: Deploy to Staging
  deploy-staging:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/develop'
    environment: staging
    steps:
    - name: Deploy to staging
      run: |
        echo "Deploying to staging environment"
        echo "Image digest: ${{ needs.build.outputs.image-digest }}"
        # Add actual deployment commands here

  # Stage 6: Deploy to Production
  deploy-production:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
    - name: Deploy to production
      run: |
        echo "Deploying to production environment"
        echo "Image digest: ${{ needs.build.outputs.image-digest }}"
        # Add actual deployment commands here
```

#### Artifact Management:
```yaml
# .github/workflows/artifacts.yml
name: Build Artifacts

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
    
    - name: Install and build
      run: |
        npm ci
        npm run build
    
    - name: Upload build artifacts
      uses: actions/upload-artifact@v4
      with:
        name: build-files
        path: |
          dist/
          !dist/**/*.map
        retention-days: 30
    
    - name: Upload test results
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: test-results
        path: |
          coverage/
          test-results.xml

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
    - name: Download build artifacts
      uses: actions/download-artifact@v4
      with:
        name: build-files
        path: ./dist
    
    - name: Deploy artifacts
      run: |
        ls -la ./dist
        # Deploy the downloaded artifacts
```

#### Parallel Jobs with Approval Gates:
```yaml
# .github/workflows/approval-gates.yml
name: Production Deployment with Approval

on:
  push:
    branches: [ main ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Build and test
      run: |
        echo "Building and testing application"
        # Add build and test commands

  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Security scanning
      run: |
        echo "Running security scans"
        # Add security scanning commands

  deploy-staging:
    needs: [build-and-test, security-scan]
    runs-on: ubuntu-latest
    environment: staging
    steps:
    - name: Deploy to staging
      run: echo "Deployed to staging"

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production  # This environment requires manual approval
    steps:
    - name: Deploy to production
      run: echo "Deployed to production"
```

#### Reusable Workflows:
```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deployment

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      image-tag:
        required: true
        type: string
    secrets:
      aws-access-key-id:
        required: true
      aws-secret-access-key:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.aws-access-key-id }}
        aws-secret-access-key: ${{ secrets.aws-secret-access-key }}
        aws-region: us-east-1
    
    - name: Deploy application
      run: |
        echo "Deploying ${{ inputs.image-tag }} to ${{ inputs.environment }}"
        # Add deployment commands
```

#### Using Reusable Workflow:
```yaml
# .github/workflows/main-pipeline.yml
name: Main Pipeline

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    steps:
    - name: Build image
      id: meta
      run: echo "tags=myapp:${{ github.sha }}" >> $GITHUB_OUTPUT

  deploy-staging:
    needs: build
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: staging
      image-tag: ${{ needs.build.outputs.image-tag }}
    secrets:
      aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
      aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

**Tasks:**
- [ ] Implement the multi-stage pipeline above
- [ ] Set up artifact management for your project
- [ ] Create reusable workflows
- [ ] Configure environment protection rules with approvals

### Day 3: Deployment Strategies
- [ ] Learn blue-green deployments
- [ ] Implement canary releases
- [ ] Practice rolling updates
- [ ] Set up rollback mechanisms

### Day 4: Infrastructure Pipelines
- [ ] Automate Terraform deployments
- [ ] Implement infrastructure testing
- [ ] Set up environment promotion
- [ ] Practice: GitOps workflow

### Day 5: Monitoring & Alerting
- [ ] Set up application monitoring
- [ ] Configure log aggregation
- [ ] Create alerting rules
- [ ] Practice: Incident response

## Hands-on Lab: Complete CI/CD Pipeline

```yaml
# .github/workflows/deploy.yml
name: Deploy Application
on:
  push:
    branches: [main]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: npm test
  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to AWS
        run: |
          terraform apply -auto-approve
          kubectl apply -f k8s/
```

## Assessment
- [ ] Build end-to-end CI/CD pipeline
- [ ] Implement automated testing
- [ ] Deploy to multiple environments
- [ ] Set up monitoring and alerts
