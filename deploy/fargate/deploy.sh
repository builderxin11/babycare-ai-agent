#!/bin/bash
# CalmDownDad ECS Fargate Deployment Script
# Usage: ./deploy.sh [build|push|deploy|all|status|logs|destroy]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STACK_NAME="${STACK_NAME:-calmdowndad-fargate}"
AWS_REGION="${AWS_REGION:-us-west-2}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
ECR_REPO_NAME="${ECR_REPO_NAME:-calmdowndad}"

# Load environment variables if .env exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
fi

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing=()

    command -v aws >/dev/null 2>&1 || missing+=("aws-cli")
    command -v docker >/dev/null 2>&1 || missing+=("docker")

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}Missing required tools: ${missing[*]}${NC}"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${RED}AWS credentials not configured. Run 'aws configure'${NC}"
        exit 1
    fi

    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

    echo -e "${GREEN}AWS Account: ${AWS_ACCOUNT_ID}${NC}"
    echo -e "${GREEN}Region: ${AWS_REGION}${NC}"
    echo -e "${GREEN}ECR URI: ${ECR_URI}${NC}"
}

create_ecr_repo() {
    print_header "Creating ECR Repository (if not exists)"

    if aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        echo "ECR repository '$ECR_REPO_NAME' already exists"
    else
        echo "Creating ECR repository '$ECR_REPO_NAME'..."
        aws ecr create-repository \
            --repository-name "$ECR_REPO_NAME" \
            --region "$AWS_REGION" \
            --image-scanning-configuration scanOnPush=true
        echo -e "${GREEN}ECR repository created${NC}"
    fi
}

build_image() {
    print_header "Building Docker Image"

    cd "$PROJECT_ROOT"

    echo "Building image: ${ECR_REPO_NAME}:latest"
    docker build -f deploy/Dockerfile -t "${ECR_REPO_NAME}:latest" .

    echo -e "${GREEN}Build complete${NC}"
}

push_image() {
    print_header "Pushing to ECR"

    # Login to ECR
    echo "Logging in to ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

    # Tag and push
    docker tag "${ECR_REPO_NAME}:latest" "${ECR_URI}:latest"
    docker tag "${ECR_REPO_NAME}:latest" "${ECR_URI}:$(date +%Y%m%d-%H%M%S)"

    echo "Pushing image to ECR..."
    docker push "${ECR_URI}:latest"

    echo -e "${GREEN}Push complete: ${ECR_URI}:latest${NC}"
}

deploy_stack() {
    print_header "Deploying CloudFormation Stack"

    # Check required parameters
    local required_params=("VPC_ID" "SUBNET_IDS" "BABY_TABLE" "PHYSIOLOGY_LOG_TABLE" "CONTEXT_EVENT_TABLE" "COGNITO_USER_POOL_ID")
    local missing_params=()

    for param in "${required_params[@]}"; do
        if [ -z "${!param}" ]; then
            missing_params+=("$param")
        fi
    done

    if [ ${#missing_params[@]} -ne 0 ]; then
        echo -e "${RED}Missing required parameters: ${missing_params[*]}${NC}"
        echo ""
        echo "Create deploy/fargate/.env with:"
        echo "  VPC_ID=vpc-xxxxx"
        echo "  SUBNET_IDS=subnet-xxx,subnet-yyy"
        echo "  BABY_TABLE=Baby-xxxxx-NONE"
        echo "  PHYSIOLOGY_LOG_TABLE=PhysiologyLog-xxxxx-NONE"
        echo "  CONTEXT_EVENT_TABLE=ContextEvent-xxxxx-NONE"
        echo "  COGNITO_USER_POOL_ID=us-west-2_xxxxx"
        echo "  BEDROCK_KB_ID=xxxxx (optional)"
        echo "  XHS_MCP_URL=http://x.x.x.x:3000 (optional)"
        exit 1
    fi

    echo "Deploying stack: ${STACK_NAME}"
    echo "  Environment: ${ENVIRONMENT}"
    echo "  VPC: ${VPC_ID}"
    echo "  Subnets: ${SUBNET_IDS}"

    aws cloudformation deploy \
        --stack-name "$STACK_NAME" \
        --template-file "$SCRIPT_DIR/cloudformation.yaml" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION" \
        --parameter-overrides \
            Environment="$ENVIRONMENT" \
            VpcId="$VPC_ID" \
            SubnetIds="$SUBNET_IDS" \
            ContainerImage="${ECR_URI}:latest" \
            BabyTable="$BABY_TABLE" \
            PhysiologyLogTable="$PHYSIOLOGY_LOG_TABLE" \
            ContextEventTable="$CONTEXT_EVENT_TABLE" \
            CognitoUserPoolId="$COGNITO_USER_POOL_ID" \
            CognitoRegion="${COGNITO_REGION:-$AWS_REGION}" \
            BedrockKbId="${BEDROCK_KB_ID:-}" \
            XhsMcpUrl="${XHS_MCP_URL:-}" \
            TaskCpu="${TASK_CPU:-512}" \
            TaskMemory="${TASK_MEMORY:-1024}" \
            DesiredCount="${DESIRED_COUNT:-1}"

    echo ""
    echo -e "${GREEN}Deployment complete!${NC}"

    # Get outputs
    echo ""
    print_header "Stack Outputs"
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs' \
        --output table
}

show_status() {
    print_header "Service Status"

    # Get cluster and service names
    local cluster_name=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' \
        --output text 2>/dev/null)

    local service_name=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ServiceName`].OutputValue' \
        --output text 2>/dev/null)

    if [ -z "$cluster_name" ] || [ -z "$service_name" ]; then
        echo -e "${YELLOW}Stack not found or not deployed${NC}"
        return 1
    fi

    echo "Cluster: $cluster_name"
    echo "Service: $service_name"
    echo ""

    # Show service status
    aws ecs describe-services \
        --cluster "$cluster_name" \
        --services "$service_name" \
        --region "$AWS_REGION" \
        --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}' \
        --output table

    # Show tasks
    echo ""
    echo "Tasks:"
    aws ecs list-tasks \
        --cluster "$cluster_name" \
        --service-name "$service_name" \
        --region "$AWS_REGION" \
        --query 'taskArns' \
        --output table

    # Show ALB URL
    echo ""
    local api_url=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`APIURL`].OutputValue' \
        --output text)

    echo -e "${GREEN}API URL: ${api_url}${NC}"
    echo ""
    echo "Test with: curl ${api_url}/health"
}

show_logs() {
    print_header "Recent Logs"

    local log_group="/ecs/calmdowndad-${ENVIRONMENT}"

    echo "Log group: $log_group"
    echo ""

    aws logs tail "$log_group" \
        --region "$AWS_REGION" \
        --since 30m \
        --follow
}

update_service() {
    print_header "Force New Deployment"

    local cluster_name=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' \
        --output text)

    local service_name=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ServiceName`].OutputValue' \
        --output text)

    echo "Forcing new deployment..."
    aws ecs update-service \
        --cluster "$cluster_name" \
        --service "$service_name" \
        --force-new-deployment \
        --region "$AWS_REGION" \
        --query 'service.{Status:status,Deployments:deployments[*].status}' \
        --output table

    echo -e "${GREEN}Deployment triggered. Use './deploy.sh status' to monitor.${NC}"
}

destroy_stack() {
    print_header "Destroying Stack"

    echo -e "${RED}WARNING: This will delete all resources in stack '${STACK_NAME}'${NC}"
    read -p "Are you sure? (type 'yes' to confirm): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "Aborted"
        exit 0
    fi

    echo "Deleting stack..."
    aws cloudformation delete-stack \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION"

    echo "Waiting for deletion..."
    aws cloudformation wait stack-delete-complete \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION"

    echo -e "${GREEN}Stack deleted${NC}"
}

show_help() {
    echo "CalmDownDad ECS Fargate Deployment"
    echo ""
    echo "Usage: ./deploy.sh [command]"
    echo ""
    echo "Commands:"
    echo "  build    Build Docker image locally"
    echo "  push     Push image to ECR"
    echo "  deploy   Deploy/update CloudFormation stack"
    echo "  all      Build, push, and deploy"
    echo "  update   Force new deployment (pull latest image)"
    echo "  status   Show service status"
    echo "  logs     Tail CloudWatch logs"
    echo "  destroy  Delete the stack"
    echo ""
    echo "Environment variables (or set in .env):"
    echo "  AWS_REGION           AWS region (default: us-west-2)"
    echo "  ENVIRONMENT          Environment name (default: prod)"
    echo "  STACK_NAME           CloudFormation stack name"
    echo "  VPC_ID               VPC ID (required for deploy)"
    echo "  SUBNET_IDS           Comma-separated subnet IDs (required)"
    echo "  BABY_TABLE           DynamoDB Baby table name (required)"
    echo "  PHYSIOLOGY_LOG_TABLE DynamoDB PhysiologyLog table (required)"
    echo "  CONTEXT_EVENT_TABLE  DynamoDB ContextEvent table (required)"
    echo "  COGNITO_USER_POOL_ID Cognito User Pool ID (required)"
    echo "  BEDROCK_KB_ID        Bedrock Knowledge Base ID (optional)"
    echo "  XHS_MCP_URL          XHS MCP server URL (optional)"
}

# Main
check_prerequisites

case "${1:-help}" in
    build)
        create_ecr_repo
        build_image
        ;;
    push)
        push_image
        ;;
    deploy)
        deploy_stack
        ;;
    all)
        create_ecr_repo
        build_image
        push_image
        deploy_stack
        ;;
    update)
        push_image
        update_service
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    destroy)
        destroy_stack
        ;;
    *)
        show_help
        ;;
esac
