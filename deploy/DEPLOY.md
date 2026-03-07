# CalmDownDad Deployment Guide

This guide covers two deployment options:
1. **ECS Fargate** (Recommended for production) - Managed, scalable, no servers to manage
2. **EC2 Docker** - For development or when you need VNC access for XHS MCP login

---

## Option 1: ECS Fargate (Recommended)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      ECS Fargate                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │   FastAPI Agent Service (Auto-scaling)              │   │
│  │   - Data Scientist, Medical Expert, Social Researcher│   │
│  └───────────────────────────┬─────────────────────────┘   │
│                              │                              │
│  ┌───────────────────────────▼─────────────────────────┐   │
│  │   Application Load Balancer                         │   │
│  └─────────────────────────────────────────────────────┘   │
└──────────────────────────────┼─────────────────────────────┘
                               │ (Optional)
┌──────────────────────────────▼─────────────────────────────┐
│                    EC2 t3.micro (Optional)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │   XHS MCP Server + VNC (for Xiaohongshu login)     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Prerequisites

- AWS CLI configured (`aws configure`)
- Docker installed
- VPC with at least 2 subnets in different AZs

### Quick Deploy

```bash
cd deploy/fargate

# 1. Copy and configure environment
cp .env.example .env
nano .env  # Fill in VPC_ID, SUBNET_IDS, table names, etc.

# 2. Deploy everything (build, push to ECR, deploy CloudFormation)
chmod +x deploy.sh
./deploy.sh all
```

### Step-by-Step Deploy

```bash
# Build Docker image
./deploy.sh build

# Push to ECR
./deploy.sh push

# Deploy CloudFormation stack
./deploy.sh deploy
```

### Management Commands

```bash
# Check service status
./deploy.sh status

# View logs
./deploy.sh logs

# Force new deployment (after code changes)
./deploy.sh update

# Delete everything
./deploy.sh destroy
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| VPC_ID | Yes | VPC to deploy into |
| SUBNET_IDS | Yes | At least 2 subnets (comma-separated) |
| BABY_TABLE | Yes | DynamoDB table from Amplify |
| PHYSIOLOGY_LOG_TABLE | Yes | DynamoDB table from Amplify |
| CONTEXT_EVENT_TABLE | Yes | DynamoDB table from Amplify |
| COGNITO_USER_POOL_ID | Yes | Cognito pool from Amplify |
| BEDROCK_KB_ID | No | Bedrock Knowledge Base ID |
| XHS_MCP_URL | No | XHS MCP server URL (if using) |

### Adding XHS MCP Support (Optional)

If you need Xiaohongshu social consensus, deploy the XHS MCP on a small EC2 instance:

1. Launch EC2 t3.micro in the same VPC
2. Follow [EC2 XHS MCP Setup](#step-5-login-to-xiaohongshu) below
3. Set `XHS_MCP_URL=http://<EC2_PRIVATE_IP>:3000` in Fargate config

### Cost Estimate

| Resource | Estimated Cost |
|----------|---------------|
| Fargate (0.5 vCPU, 1GB) | ~$15/month |
| ALB | ~$20/month |
| ECR | ~$1/month |
| XHS MCP EC2 (optional) | ~$8/month |
| **Total** | **~$35-45/month** |

---

## Option 2: EC2 Docker (All-in-One)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        EC2 Instance                          │
│  ┌─────────────────┐    ┌────────────────────────────────┐  │
│  │   FastAPI       │    │  XHS MCP + VNC Desktop         │  │
│  │   (Port 8000)   │───▶│  (Port 3000 MCP, 6080 VNC)    │  │
│  └─────────────────┘    └────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
    iOS App / Web                 Browser (Login)
```

## Prerequisites

- AWS Account with EC2 access
- EC2 instance: t3.medium or larger (need 4GB+ RAM for Chrome)
- Security Group allowing: 8000, 6080, 22

## Step 1: Launch EC2 Instance

1. Go to AWS Console → EC2 → Launch Instance
2. Choose **Ubuntu 22.04 LTS** (recommended)
3. Instance type: **t3.medium** (2 vCPU, 4GB RAM)
4. Configure Security Group:
   - SSH (22) from your IP
   - Custom TCP (8000) from anywhere (API)
   - Custom TCP (6080) from your IP (VNC - restrict for security!)
5. Launch with your key pair

## Step 2: Setup EC2

```bash
# SSH into your instance
ssh -i your-key.pem ubuntu@YOUR_EC2_IP

# Clone the repo
git clone https://github.com/YOUR_USERNAME/babycare-ai-agent.git /opt/calmdowndad
cd /opt/calmdowndad

# Run setup script
chmod +x deploy/scripts/setup-ec2.sh
./deploy/scripts/setup-ec2.sh

# IMPORTANT: Log out and log back in for docker group
exit
ssh -i your-key.pem ubuntu@YOUR_EC2_IP
```

## Step 3: Configure Environment

```bash
cd /opt/calmdowndad/deploy

# Copy and edit environment file
cp .env.example .env
nano .env
```

Fill in the values:

```env
# Get these from: npx ampx sandbox (run locally first)
BABY_TABLE=Baby-xxxxx-NONE
PHYSIOLOGY_LOG_TABLE=PhysiologyLog-xxxxx-NONE
CONTEXT_EVENT_TABLE=ContextEvent-xxxxx-NONE

# Get from Amplify console or amplify_outputs.json
COGNITO_USER_POOL_ID=us-west-2_xxxxxxx

# Get from Bedrock console
BEDROCK_KB_ID=xxxxxxxxxx

# Your AWS credentials (or use IAM role)
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...

# VNC password (choose a strong one)
VNC_PASSWORD=YourSecurePassword123
```

## Step 4: Deploy

```bash
cd /opt/calmdowndad/deploy

# Build and start services
docker compose up -d --build

# Check logs
docker compose logs -f
```

## Step 5: Login to Xiaohongshu

1. Open browser: `http://YOUR_EC2_IP:6080`
2. Enter VNC password
3. In the desktop, open terminal and run:
   ```bash
   google-chrome --no-sandbox https://xiaohongshu.com
   ```
4. Login with your Xiaohongshu account (QR code or password)
5. Close the browser - the session is now saved

## Step 6: Verify

```bash
# Test API health
curl http://YOUR_EC2_IP:8000/health

# Test XHS MCP (from EC2)
curl -X POST http://localhost:3000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

## Maintenance

### Re-login to Xiaohongshu

When XHS session expires (usually every 1-2 weeks):

1. Open `http://YOUR_EC2_IP:6080`
2. Login to Xiaohongshu again
3. That's it!

### Check Service Status

```bash
cd /opt/calmdowndad/deploy
docker compose ps
docker compose logs api
docker compose logs xhs-mcp
```

### Restart Services

```bash
docker compose restart
```

### Update Code

```bash
cd /opt/calmdowndad
git pull
cd deploy
docker compose up -d --build
```

## Security Recommendations

1. **Restrict VNC access**: Only allow your IP in Security Group for port 6080
2. **Use IAM Role**: Instead of hardcoding AWS credentials, attach an IAM role to EC2
3. **HTTPS**: Put behind ALB or nginx with SSL certificate
4. **VNC Password**: Use a strong, unique password

## Troubleshooting

### API not responding
```bash
docker compose logs api
docker compose restart api
```

### XHS MCP failing
```bash
# Check if login expired
docker compose logs xhs-mcp

# Re-login via VNC
# Open http://YOUR_EC2_IP:6080
```

### Out of memory
- Upgrade to t3.large (8GB RAM)
- Or add swap:
  ```bash
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  ```
