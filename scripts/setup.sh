#!/bin/bash
# NurtureMind One-Click Setup Script
# Usage: ./scripts/setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        return 1
    fi
    return 0
}

# Header
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           NurtureMind - AI Parenting Assistant                ║"
echo "║                    One-Click Setup                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Check prerequisites
print_step "Checking prerequisites..."

MISSING_DEPS=""

if ! check_command node; then
    MISSING_DEPS="$MISSING_DEPS node"
fi

if ! check_command npm; then
    MISSING_DEPS="$MISSING_DEPS npm"
fi

if ! check_command python3; then
    MISSING_DEPS="$MISSING_DEPS python3"
fi

if ! check_command pip3 && ! check_command pip; then
    MISSING_DEPS="$MISSING_DEPS pip"
fi

if ! check_command aws; then
    MISSING_DEPS="$MISSING_DEPS aws-cli"
fi

if [ -n "$MISSING_DEPS" ]; then
    print_error "Missing dependencies:$MISSING_DEPS"
    echo ""
    echo "Please install the missing dependencies:"
    echo "  - Node.js: https://nodejs.org/"
    echo "  - Python: https://python.org/"
    echo "  - AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

print_success "All prerequisites found"

# Check versions
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)

echo "  Node.js: $(node -v)"
echo "  Python: $(python3 --version)"
echo "  AWS CLI: $(aws --version | cut -d' ' -f1)"

if [ "$NODE_VERSION" -lt 18 ]; then
    print_warning "Node.js 18+ recommended (you have v$NODE_VERSION)"
fi

# Step 2: Check AWS credentials
print_step "Checking AWS credentials..."

if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text | rev | cut -d'/' -f1 | rev)
    print_success "AWS configured: $AWS_USER (Account: $AWS_ACCOUNT)"
else
    print_warning "AWS credentials not configured"
    echo ""
    echo "Would you like to configure AWS credentials now? (y/n)"
    read -r CONFIGURE_AWS

    if [ "$CONFIGURE_AWS" = "y" ] || [ "$CONFIGURE_AWS" = "Y" ]; then
        aws configure
    else
        print_warning "Skipping AWS configuration. You'll need to run 'aws configure' later."
    fi
fi

# Step 3: Install Node.js dependencies
print_step "Installing Node.js dependencies..."

if [ -f "package.json" ]; then
    npm install
    print_success "Node.js dependencies installed"
else
    print_warning "No package.json found, skipping npm install"
fi

# Step 4: Install Python dependencies
print_step "Installing Python dependencies..."

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
if [ -f "pyproject.toml" ]; then
    pip install -e ".[dev]"
    print_success "Python dependencies installed"
else
    print_warning "No pyproject.toml found, skipping pip install"
fi

# Step 5: Configure git author
print_step "Configuring git..."

CURRENT_NAME=$(git config user.name 2>/dev/null || echo "")
CURRENT_EMAIL=$(git config user.email 2>/dev/null || echo "")

if [ -z "$CURRENT_NAME" ] || [ -z "$CURRENT_EMAIL" ]; then
    echo "Git author not configured."
    echo "Enter your name (e.g., 'John Doe'):"
    read -r GIT_NAME
    echo "Enter your email:"
    read -r GIT_EMAIL

    git config user.name "$GIT_NAME"
    git config user.email "$GIT_EMAIL"
    print_success "Git configured: $GIT_NAME <$GIT_EMAIL>"
else
    print_success "Git already configured: $CURRENT_NAME <$CURRENT_EMAIL>"
fi

# Step 6: Create .env file
print_step "Setting up environment variables..."

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_success "Created .env from .env.example"
    else
        cat > .env << 'EOF'
# AWS Configuration
AWS_REGION=us-west-2

# Amplify/DynamoDB Tables (fill after running 'npx ampx sandbox')
BABY_TABLE=
PHYSIOLOGY_LOG_TABLE=
CONTEXT_EVENT_TABLE=

# Cognito (fill after running 'npx ampx sandbox')
COGNITO_USER_POOL_ID=

# Bedrock Knowledge Base (create in AWS Console)
BEDROCK_KB_ID=

# Xiaohongshu MCP (optional, for social research feature)
XHS_MCP_URL=
EOF
        print_success "Created .env template"
    fi
    print_warning "Please edit .env with your configuration values"
else
    print_success ".env already exists"
fi

# Step 7: Deploy Amplify backend (optional)
print_step "Amplify Backend Setup"

echo ""
echo "Would you like to deploy Amplify backend now? (y/n)"
echo "This will create Cognito, DynamoDB tables, and AppSync API in your AWS account."
read -r DEPLOY_AMPLIFY

if [ "$DEPLOY_AMPLIFY" = "y" ] || [ "$DEPLOY_AMPLIFY" = "Y" ]; then
    echo ""
    echo "Choose deployment mode:"
    echo "  1) Sandbox (development, auto-deploys on file changes)"
    echo "  2) Production (one-time deploy)"
    read -r DEPLOY_MODE

    if [ "$DEPLOY_MODE" = "1" ]; then
        echo ""
        echo "Starting Amplify sandbox..."
        echo "Press Ctrl+C when you see 'Watching for file changes...'"
        echo ""
        npx ampx sandbox
    elif [ "$DEPLOY_MODE" = "2" ]; then
        npx ampx pipeline-deploy --branch main
    fi
else
    print_warning "Skipping Amplify deployment. Run 'npx ampx sandbox' later."
fi

# Step 8: Summary
echo ""
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    Setup Complete!                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo "Next steps:"
echo ""
echo "  1. Edit .env with your configuration values"
echo "     - After 'npx ampx sandbox', check amplify_outputs.json for table names"
echo "     - Create a Bedrock Knowledge Base and add the ID"
echo ""
echo "  2. Start the development server:"
echo "     ${BLUE}source venv/bin/activate${NC}"
echo "     ${BLUE}uvicorn src.api.server:app --reload --port 8000${NC}"
echo ""
echo "  3. Run tests:"
echo "     ${BLUE}pytest src/eval/ -v${NC}"
echo ""
echo "  4. For EC2 deployment, see: ${BLUE}deploy/DEPLOY.md${NC}"
echo ""
echo "Documentation: ${BLUE}README.md${NC}"
echo "Issues: ${BLUE}https://github.com/builderxin11/babycare-ai-agent/issues${NC}"
