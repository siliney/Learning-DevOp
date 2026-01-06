# Week 3: CI/CD Pipelines & Automation

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

### Day 3: Deployment Strategies & Patterns

#### Why Deployment Strategies Matter?
Different deployment strategies minimize risk, reduce downtime, and enable safe releases. Choosing the right strategy depends on your application requirements and risk tolerance.

#### Blue-Green Deployment:
Two identical production environments - only one serves traffic at a time. Instant rollback capability with zero downtime.

```yaml
# blue-green-deployment.yml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: web-app-rollout
spec:
  replicas: 5
  strategy:
    blueGreen:
      activeService: web-app-active
      previewService: web-app-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: web-app-preview
      postPromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: web-app-active
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
        image: myapp:latest
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-active
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-preview
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 8080
```

#### Blue-Green with GitHub Actions:
```yaml
# .github/workflows/blue-green-deploy.yml
name: Blue-Green Deployment

on:
  push:
    branches: [main]

env:
  AWS_REGION: us-east-1
  EKS_CLUSTER: production-cluster

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Update kubeconfig
      run: aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name ${{ env.EKS_CLUSTER }}
    
    - name: Install Argo Rollouts CLI
      run: |
        curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
        chmod +x ./kubectl-argo-rollouts-linux-amd64
        sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
    
    - name: Deploy new version
      run: |
        # Update image tag
        kubectl argo rollouts set image web-app-rollout web-app=myapp:${{ github.sha }}
        
        # Wait for rollout to be ready for promotion
        kubectl argo rollouts get rollout web-app-rollout --watch
    
    - name: Run smoke tests
      run: |
        # Get preview service endpoint
        PREVIEW_URL=$(kubectl get svc web-app-preview -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        
        # Run smoke tests against preview environment
        curl -f http://$PREVIEW_URL/health || exit 1
        curl -f http://$PREVIEW_URL/api/status || exit 1
        
        # Run more comprehensive tests
        npm run test:smoke -- --url=http://$PREVIEW_URL
    
    - name: Promote deployment
      run: |
        # Promote to active if tests pass
        kubectl argo rollouts promote web-app-rollout
        
        # Wait for promotion to complete
        kubectl argo rollouts get rollout web-app-rollout --watch
    
    - name: Verify deployment
      run: |
        # Verify active service is serving new version
        ACTIVE_URL=$(kubectl get svc web-app-active -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        curl -f http://$ACTIVE_URL/version | grep ${{ github.sha }}
```

#### Canary Deployment:
Gradually shift traffic from old to new version, monitoring metrics to detect issues early.

```yaml
# canary-deployment.yml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: web-app-canary
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 20
      - pause: {duration: 2m}
      - setWeight: 50
      - pause: {duration: 2m}
      - setWeight: 80
      - pause: {duration: 2m}
      analysis:
        templates:
        - templateName: success-rate
        - templateName: latency
        args:
        - name: service-name
          value: web-app-canary
      trafficRouting:
        nginx:
          stableService: web-app-stable
          canaryService: web-app-canary
          annotationPrefix: nginx.ingress.kubernetes.io
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
        image: myapp:latest
        ports:
        - containerPort: 8080
---
# Analysis Template for success rate
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 30s
    count: 5
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{service="{{args.service-name}}",status!~"5.."}[2m])) /
          sum(rate(http_requests_total{service="{{args.service-name}}"}[2m]))
---
# Analysis Template for latency
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: latency
spec:
  args:
  - name: service-name
  metrics:
  - name: latency
    interval: 30s
    count: 5
    successCondition: result[0] <= 0.5
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket{service="{{args.service-name}}"}[2m])) by (le)
          )
```

#### Rolling Deployment:
Standard Kubernetes deployment strategy - gradually replace old pods with new ones.

```yaml
# rolling-deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-rolling
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # Can create 2 extra pods during update
      maxUnavailable: 1  # At most 1 pod can be unavailable
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
        image: myapp:latest
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
```

#### Feature Flags for Safe Deployments:
```javascript
// feature-flags.js
class FeatureFlags {
    constructor() {
        this.flags = new Map();
        this.loadFlags();
    }
    
    async loadFlags() {
        try {
            // Load from configuration service or environment
            const response = await fetch('/api/feature-flags');
            const flags = await response.json();
            
            Object.entries(flags).forEach(([key, value]) => {
                this.flags.set(key, value);
            });
        } catch (error) {
            console.error('Failed to load feature flags:', error);
        }
    }
    
    isEnabled(flagName, userId = null, percentage = 0) {
        const flag = this.flags.get(flagName);
        
        if (!flag) return false;
        if (!flag.enabled) return false;
        
        // Percentage rollout
        if (percentage > 0 && userId) {
            const hash = this.hashUserId(userId);
            return (hash % 100) < percentage;
        }
        
        return flag.enabled;
    }
    
    hashUserId(userId) {
        let hash = 0;
        for (let i = 0; i < userId.length; i++) {
            const char = userId.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash; // Convert to 32-bit integer
        }
        return Math.abs(hash);
    }
}

// Usage in application
const featureFlags = new FeatureFlags();

app.get('/api/users', async (req, res) => {
    const userId = req.user.id;
    
    if (featureFlags.isEnabled('new-user-api', userId, 25)) {
        // 25% of users get new API
        return res.json(await getUsersV2());
    } else {
        // 75% get old API
        return res.json(await getUsers());
    }
});
```

#### Deployment Automation Script:
```bash
#!/bin/bash
# deploy.sh - Automated deployment script

set -e

DEPLOYMENT_TYPE=${1:-rolling}
IMAGE_TAG=${2:-latest}
NAMESPACE=${3:-default}

echo "Starting $DEPLOYMENT_TYPE deployment..."

case $DEPLOYMENT_TYPE in
    "blue-green")
        echo "Deploying with Blue-Green strategy"
        kubectl argo rollouts set image web-app-rollout web-app=myapp:$IMAGE_TAG -n $NAMESPACE
        kubectl argo rollouts get rollout web-app-rollout -n $NAMESPACE --watch
        
        # Run smoke tests
        echo "Running smoke tests..."
        ./scripts/smoke-tests.sh preview
        
        # Promote if tests pass
        echo "Promoting deployment..."
        kubectl argo rollouts promote web-app-rollout -n $NAMESPACE
        ;;
        
    "canary")
        echo "Deploying with Canary strategy"
        kubectl argo rollouts set image web-app-canary web-app=myapp:$IMAGE_TAG -n $NAMESPACE
        kubectl argo rollouts get rollout web-app-canary -n $NAMESPACE --watch
        ;;
        
    "rolling")
        echo "Deploying with Rolling Update strategy"
        kubectl set image deployment/web-app-rolling web-app=myapp:$IMAGE_TAG -n $NAMESPACE
        kubectl rollout status deployment/web-app-rolling -n $NAMESPACE --timeout=300s
        ;;
        
    *)
        echo "Unknown deployment type: $DEPLOYMENT_TYPE"
        echo "Supported types: blue-green, canary, rolling"
        exit 1
        ;;
esac

echo "Deployment completed successfully!"

# Verify deployment
echo "Verifying deployment..."
kubectl get pods -l app=web-app -n $NAMESPACE
kubectl get services -n $NAMESPACE

# Run post-deployment tests
echo "Running post-deployment tests..."
./scripts/integration-tests.sh $NAMESPACE

echo "All tests passed! Deployment verified."
```

**Tasks:**
- [ ] Implement blue-green deployment with Argo Rollouts
- [ ] Set up canary deployment with traffic splitting
- [ ] Create feature flags system
- [ ] Practice different deployment strategies

### Day 4: GitOps Workflows & Infrastructure Pipelines

#### What is GitOps?
GitOps uses Git as the single source of truth for infrastructure and applications. Changes are made via pull requests, and automated systems sync the desired state from Git to production.

#### GitOps Principles:
1. **Declarative**: System described declaratively
2. **Versioned**: Desired state stored in Git
3. **Pulled**: Software agents pull desired state
4. **Continuously Reconciled**: Agents ensure actual state matches desired state

#### ArgoCD Setup for GitOps:
```yaml
# argocd-install.yml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-server-config
  namespace: argocd
data:
  url: https://argocd.example.com
  application.instanceLabelKey: argocd.argoproj.io/instance
---
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose ArgoCD server
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### Application Configuration:
```yaml
# applications/web-app.yml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/k8s-manifests
    targetRevision: HEAD
    path: applications/web-app
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
---
# App of Apps pattern
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/k8s-manifests
    targetRevision: HEAD
    path: applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

#### Infrastructure as Code Pipeline:
```yaml
# .github/workflows/infrastructure-gitops.yml
name: Infrastructure GitOps

on:
  push:
    paths:
      - 'infrastructure/**'
    branches: [main]
  pull_request:
    paths:
      - 'infrastructure/**'

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Terraform Init
      run: terraform init
      working-directory: ./infrastructure
    
    - name: Terraform Plan
      run: terraform plan -no-color
      working-directory: ./infrastructure
      continue-on-error: true
      id: plan
    
    - name: Comment PR
      uses: actions/github-script@v6
      with:
        script: |
          const output = `#### Terraform Plan 📖
          
          \`\`\`
          ${{ steps.plan.outputs.stdout }}
          \`\`\`
          
          *Pusher: @${{ github.actor }}, Action: \`${{ github.event_name }}\`*`;
          
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: output
          })

  terraform-apply:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Terraform Init
      run: terraform init
      working-directory: ./infrastructure
    
    - name: Terraform Apply
      run: terraform apply -auto-approve
      working-directory: ./infrastructure
    
    - name: Update Kubernetes manifests
      run: |
        # Update image tags or configuration in k8s manifests
        sed -i "s/image: myapp:.*/image: myapp:${{ github.sha }}/g" k8s/production/deployment.yaml
        
        # Commit changes to trigger ArgoCD sync
        git config --local user.email "action@github.com"
        git config --local user.name "GitHub Action"
        git add k8s/
        git commit -m "Update image tag to ${{ github.sha }}" || exit 0
        git push
```

#### Kustomize for Environment Management:
```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- configmap.yaml

commonLabels:
  app: web-app
  version: v1.0.0

images:
- name: myapp
  newTag: latest
```

```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

patchesStrategicMerge:
- deployment-patch.yaml
- configmap-patch.yaml

replicas:
- name: web-app
  count: 5

images:
- name: myapp
  newTag: v1.2.3

configMapGenerator:
- name: app-config
  literals:
  - DATABASE_URL=postgresql://prod-db:5432/myapp
  - LOG_LEVEL=info
  - ENVIRONMENT=production
```

```yaml
# overlays/production/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  template:
    spec:
      containers:
      - name: web-app
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        env:
        - name: ENVIRONMENT
          value: "production"
```

#### Helm Charts for Complex Applications:
```yaml
# Chart.yaml
apiVersion: v2
name: web-app
description: A Helm chart for web application
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
- name: postgresql
  version: 11.9.13
  repository: https://charts.bitnami.com/bitnami
  condition: postgresql.enabled
- name: redis
  version: 17.3.7
  repository: https://charts.bitnami.com/bitnami
  condition: redis.enabled
```

```yaml
# values.yaml
replicaCount: 3

image:
  repository: myapp
  pullPolicy: IfNotPresent
  tag: "latest"

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: app-tls
      hosts:
        - app.example.com

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

postgresql:
  enabled: true
  auth:
    postgresPassword: "changeme"
    database: "myapp"

redis:
  enabled: true
  auth:
    enabled: false
```

#### GitOps Repository Structure:
```
k8s-manifests/
├── applications/
│   ├── web-app.yml
│   ├── api-service.yml
│   └── kustomization.yaml
├── infrastructure/
│   ├── namespaces/
│   ├── ingress-controllers/
│   └── monitoring/
├── environments/
│   ├── development/
│   ├── staging/
│   └── production/
└── helm-charts/
    ├── web-app/
    └── shared-services/
```

#### Automated Image Updates:
```yaml
# .github/workflows/update-manifests.yml
name: Update Kubernetes Manifests

on:
  workflow_run:
    workflows: ["Build and Push Image"]
    types:
      - completed

jobs:
  update-manifests:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
    - name: Checkout manifests repo
      uses: actions/checkout@v4
      with:
        repository: myorg/k8s-manifests
        token: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Update image tag
      run: |
        NEW_TAG=${{ github.event.workflow_run.head_sha }}
        
        # Update Kustomization
        cd environments/production
        kustomize edit set image myapp:$NEW_TAG
        
        # Update Helm values
        cd ../../helm-charts/web-app
        yq eval ".image.tag = \"$NEW_TAG\"" -i values.yaml
    
    - name: Commit and push changes
      run: |
        git config --local user.email "action@github.com"
        git config --local user.name "GitHub Action"
        git add .
        git commit -m "Update image tag to ${{ github.event.workflow_run.head_sha }}"
        git push
```

#### ArgoCD CLI Operations:
```bash
# Install ArgoCD CLI
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Login to ArgoCD
argocd login argocd.example.com --username admin --password $ARGOCD_PASSWORD

# Create application
argocd app create web-app \
  --repo https://github.com/myorg/k8s-manifests \
  --path applications/web-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production \
  --sync-policy automated

# Sync application
argocd app sync web-app

# Get application status
argocd app get web-app

# List applications
argocd app list

# Delete application
argocd app delete web-app
```

**Tasks:**
- [ ] Install and configure ArgoCD
- [ ] Create GitOps repository structure
- [ ] Set up automated infrastructure pipeline
- [ ] Implement Kustomize for environment management

### Day 5: Monitoring & Alerting Integration

#### Integrating Monitoring into CI/CD:
Monitoring should be part of your deployment pipeline, not an afterthought. Automated monitoring setup ensures consistency across environments.

#### Prometheus Setup with Helm:
```yaml
# prometheus-values.yaml
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp2
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    
    additionalScrapeConfigs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)

grafana:
  adminPassword: admin123
  persistence:
    enabled: true
    size: 10Gi
  
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default

  dashboards:
    default:
      kubernetes-cluster:
        gnetId: 7249
        revision: 1
        datasource: Prometheus
      application-metrics:
        gnetId: 6417
        revision: 1
        datasource: Prometheus

alertmanager:
  config:
    global:
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: 'alerts@example.com'
    
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'web.hook'
    
    receivers:
    - name: 'web.hook'
      email_configs:
      - to: 'admin@example.com'
        subject: 'Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
      slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#alerts'
        title: 'Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

#### Deploy Monitoring Stack:
```bash
#!/bin/bash
# deploy-monitoring.sh

# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml \
  --wait

# Verify installation
kubectl get pods -n monitoring
kubectl get svc -n monitoring

echo "Monitoring stack deployed successfully!"
echo "Grafana URL: http://$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Prometheus URL: http://$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):9090"
```

#### Application Metrics Integration:
```javascript
// metrics.js - Express.js application with Prometheus metrics
const express = require('express');
const promClient = require('prom-client');

// Create a Registry
const register = new promClient.Registry();

// Add default metrics
promClient.collectDefaultMetrics({
  app: 'web-app',
  timeout: 10000,
  gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5],
  register
});

// Custom metrics
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5],
  registers: [register]
});

const activeConnections = new promClient.Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
  registers: [register]
});

const businessMetrics = new promClient.Counter({
  name: 'orders_processed_total',
  help: 'Total number of orders processed',
  labelNames: ['status'],
  registers: [register]
});

// Middleware to collect HTTP metrics
function metricsMiddleware(req, res, next) {
  const start = Date.now();
  
  // Increment active connections
  activeConnections.inc();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    // Record metrics
    httpRequestsTotal.labels(req.method, route, res.statusCode).inc();
    httpRequestDuration.labels(req.method, route, res.statusCode).observe(duration);
    
    // Decrement active connections
    activeConnections.dec();
  });
  
  next();
}

const app = express();
app.use(metricsMiddleware);

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Business logic with metrics
app.post('/orders', (req, res) => {
  try {
    // Process order logic here
    const order = processOrder(req.body);
    
    // Record business metric
    businessMetrics.labels('success').inc();
    
    res.json({ success: true, orderId: order.id });
  } catch (error) {
    businessMetrics.labels('error').inc();
    res.status(500).json({ error: 'Order processing failed' });
  }
});

module.exports = app;
```

#### Monitoring in CI/CD Pipeline:
```yaml
# .github/workflows/deploy-with-monitoring.yml
name: Deploy with Monitoring

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Deploy application
      run: |
        kubectl apply -f k8s/
        kubectl rollout status deployment/web-app --timeout=300s
    
    - name: Wait for metrics endpoint
      run: |
        # Wait for application to be ready
        kubectl wait --for=condition=ready pod -l app=web-app --timeout=300s
        
        # Test metrics endpoint
        APP_URL=$(kubectl get svc web-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        curl -f http://$APP_URL/metrics
    
    - name: Configure monitoring
      run: |
        # Apply ServiceMonitor for Prometheus scraping
        kubectl apply -f - <<EOF
        apiVersion: monitoring.coreos.com/v1
        kind: ServiceMonitor
        metadata:
          name: web-app-metrics
          labels:
            app: web-app
        spec:
          selector:
            matchLabels:
              app: web-app
          endpoints:
          - port: http
            path: /metrics
            interval: 30s
        EOF
    
    - name: Create alerts
      run: |
        # Apply PrometheusRule for alerting
        kubectl apply -f - <<EOF
        apiVersion: monitoring.coreos.com/v1
        kind: PrometheusRule
        metadata:
          name: web-app-alerts
          labels:
            app: web-app
        spec:
          groups:
          - name: web-app.rules
            rules:
            - alert: HighErrorRate
              expr: rate(http_requests_total{status_code=~"5.."}[5m]) > 0.1
              for: 5m
              labels:
                severity: critical
              annotations:
                summary: "High error rate detected"
                description: "Error rate is {{ \$value }} errors per second"
            
            - alert: HighResponseTime
              expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "High response time detected"
                description: "95th percentile response time is {{ \$value }} seconds"
        EOF
    
    - name: Verify monitoring setup
      run: |
        # Check if ServiceMonitor is discovered
        kubectl get servicemonitor web-app-metrics
        
        # Check if PrometheusRule is loaded
        kubectl get prometheusrule web-app-alerts
        
        echo "Monitoring setup completed successfully!"
```

#### Custom Grafana Dashboard:
```json
{
  "dashboard": {
    "id": null,
    "title": "Web Application Dashboard",
    "tags": ["web-app"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{route}}"
          }
        ],
        "yAxes": [
          {
            "label": "Requests/sec"
          }
        ]
      },
      {
        "id": 2,
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          },
          {
            "expr": "histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "50th percentile"
          }
        ]
      },
      {
        "id": 3,
        "title": "Error Rate",
        "type": "singlestat",
        "targets": [
          {
            "expr": "rate(http_requests_total{status_code=~\"5..\"}[5m]) / rate(http_requests_total[5m]) * 100",
            "legendFormat": "Error Rate %"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
```

#### Log Aggregation with ELK Stack:
```yaml
# elasticsearch.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
spec:
  serviceName: elasticsearch
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:7.15.0
        env:
        - name: discovery.type
          value: single-node
        - name: ES_JAVA_OPTS
          value: "-Xms512m -Xmx512m"
        ports:
        - containerPort: 9200
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
---
# logstash.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: logstash-config
data:
  logstash.conf: |
    input {
      beats {
        port => 5044
      }
    }
    
    filter {
      if [kubernetes] {
        mutate {
          add_field => { "app" => "%{[kubernetes][labels][app]}" }
          add_field => { "namespace" => "%{[kubernetes][namespace]}" }
        }
      }
      
      if [app] == "web-app" {
        grok {
          match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:msg}" }
        }
      }
    }
    
    output {
      elasticsearch {
        hosts => ["elasticsearch:9200"]
        index => "logs-%{+YYYY.MM.dd}"
      }
    }
```

**Tasks:**
- [ ] Deploy Prometheus and Grafana with Helm
- [ ] Add metrics to your application
- [ ] Create custom Grafana dashboards
- [ ] Set up alerting rules and notifications

## 🔧 Troubleshooting Guide

### Common Issues & Solutions

#### GitHub Actions Issues
**Problem**: Workflow not triggering
**Solution**:
```yaml
# Check trigger conditions
on:
  push:
    branches: [ main ]  # Ensure branch name matches
  pull_request:
    branches: [ main ]

# Check file location: .github/workflows/filename.yml
```

**Problem**: Secrets not accessible
**Solution**:
- Verify secrets are set in repository settings
- Check secret names match exactly (case-sensitive)
- Ensure proper environment context if using environments

#### Deployment Issues
**Problem**: Blue-green deployment stuck
**Solution**:
```bash
# Check rollout status
kubectl argo rollouts get rollout app-name

# Manual promotion if needed
kubectl argo rollouts promote app-name

# Abort rollout if issues
kubectl argo rollouts abort app-name
```

**Problem**: ArgoCD sync failures
**Solution**:
```bash
# Check application status
argocd app get app-name

# Force refresh
argocd app sync app-name --force

# Check for resource conflicts
kubectl get events --sort-by=.metadata.creationTimestamp
```

#### Monitoring Issues
**Problem**: Prometheus not scraping metrics
**Solution**:
```bash
# Check ServiceMonitor configuration
kubectl get servicemonitor

# Verify service labels match ServiceMonitor selector
kubectl describe servicemonitor app-metrics

# Check Prometheus targets
# Access Prometheus UI -> Status -> Targets
```

**Problem**: Grafana dashboard not showing data
**Solution**:
- Verify data source configuration
- Check Prometheus query syntax
- Ensure time range is appropriate
- Verify metric names and labels

## 📚 Additional Resources for Week 3

### Essential Reading
- **GitHub Actions Documentation**: https://docs.github.com/en/actions
- **Argo Rollouts Guide**: https://argoproj.github.io/argo-rollouts/
- **GitOps Principles**: https://www.gitops.tech/
- **Prometheus Best Practices**: https://prometheus.io/docs/practices/

### Video Tutorials
- **CI/CD with GitHub Actions**: GitHub's official channel
- **ArgoCD Tutorial**: CNCF YouTube
- **Deployment Strategies**: TechWorld with Nana
- **Monitoring with Prometheus**: Prometheus YouTube

### Hands-on Labs
- **GitHub Actions Lab**: https://lab.github.com/
- **Argo Rollouts Workshop**: https://argoproj.github.io/argo-rollouts/
- **Prometheus Tutorial**: https://prometheus.io/docs/tutorials/
- **Grafana Tutorials**: https://grafana.com/tutorials/

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
