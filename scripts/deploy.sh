#!/bin/bash
# ==============================================================================
# OpenClaw AWS Deployment Script
# ==============================================================================
# Deploys the full CloudFormation stack in the correct order.
# Usage: ./deploy.sh [environment-name] [notification-email]
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - Region: us-east-1
# ==============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
ENV_NAME="${1:-openclaw-ronaldo}"
NOTIFICATION_EMAIL="${2:-}"
REGION="us-east-1"
CF_DIR="$(cd "$(dirname "$0")/../cloudformation" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[→]${NC} $1"; }

# --------------------------------------------------------------------------
# Pre-flight checks
# --------------------------------------------------------------------------
echo ""
echo "============================================"
echo "  OpenClaw AWS Deployment"
echo "  Environment: ${ENV_NAME}"
echo "  Region:      ${REGION}"
echo "============================================"
echo ""

# Check AWS CLI
command -v aws >/dev/null 2>&1 || err "AWS CLI not found. Install: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"

# Verify credentials
aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1 || err "AWS credentials not configured. Run 'aws configure'."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region "$REGION")
log "AWS Account: ${ACCOUNT_ID}"

# Validate all templates first
info "Validating CloudFormation templates..."
for template in 01-network.yml 03-security.yml 02-compute.yml 04-monitoring.yml; do
  aws cloudformation validate-template \
    --template-body "file://${CF_DIR}/${template}" \
    --region "$REGION" > /dev/null 2>&1 \
    && log "  ${template} — valid" \
    || err "  ${template} — INVALID"
done

# --------------------------------------------------------------------------
# Deploy function
# --------------------------------------------------------------------------
deploy_stack() {
  local STACK_NAME="$1"
  local TEMPLATE="$2"
  shift 2
  local PARAMS=("$@")

  info "Deploying: ${STACK_NAME}..."

  # Check if stack exists
  if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" > /dev/null 2>&1; then
    warn "Stack ${STACK_NAME} exists — updating..."
    ACTION="update-stack"
  else
    log "Creating stack ${STACK_NAME}..."
    ACTION="create-stack"
  fi

  # Build parameters string
  PARAM_ARGS=""
  if [ ${#PARAMS[@]} -gt 0 ]; then
    PARAM_ARGS="--parameters"
    for param in "${PARAMS[@]}"; do
      PARAM_ARGS="${PARAM_ARGS} ${param}"
    done
  fi

  # Deploy
  aws cloudformation ${ACTION} \
    --stack-name "$STACK_NAME" \
    --template-body "file://${CF_DIR}/${TEMPLATE}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" \
    ${PARAM_ARGS} \
    --tags "Key=Project,Value=${ENV_NAME}" 2>/dev/null || {
      # Check if it's a "no updates" situation
      if [ "$ACTION" = "update-stack" ]; then
        warn "No updates needed for ${STACK_NAME}"
        return 0
      fi
      err "Failed to deploy ${STACK_NAME}"
    }

  # Wait for completion
  info "Waiting for ${STACK_NAME} to complete..."
  if [ "$ACTION" = "create-stack" ]; then
    aws cloudformation wait stack-create-complete \
      --stack-name "$STACK_NAME" --region "$REGION"
  else
    aws cloudformation wait stack-update-complete \
      --stack-name "$STACK_NAME" --region "$REGION"
  fi

  log "${STACK_NAME} — deployed successfully ✓"
  echo ""
}

# --------------------------------------------------------------------------
# Deploy in order (dependencies first)
# --------------------------------------------------------------------------

# 1. Network (VPC, Subnet, IGW)
deploy_stack "${ENV_NAME}-network" "01-network.yml" \
  "ParameterKey=EnvironmentName,ParameterValue=${ENV_NAME}"

# 2. Security (Security Groups)
deploy_stack "${ENV_NAME}-security" "03-security.yml" \
  "ParameterKey=EnvironmentName,ParameterValue=${ENV_NAME}"

# 3. Compute (EC2, EBS, EIP, IAM, S3 Backup Bucket)
deploy_stack "${ENV_NAME}-compute" "02-compute.yml" \
  "ParameterKey=EnvironmentName,ParameterValue=${ENV_NAME}"

# 4. Monitoring (CloudWatch, SNS) — requires email
if [ -n "$NOTIFICATION_EMAIL" ]; then
  deploy_stack "${ENV_NAME}-monitoring" "04-monitoring.yml" \
    "ParameterKey=EnvironmentName,ParameterValue=${ENV_NAME}" \
    "ParameterKey=NotificationEmail,ParameterValue=${NOTIFICATION_EMAIL}"
else
  warn "Skipping monitoring stack — no notification email provided."
  warn "Deploy manually: ./deploy.sh ${ENV_NAME} your@email.com"
fi

# --------------------------------------------------------------------------
# Post-deployment info
# --------------------------------------------------------------------------
echo ""
echo "============================================"
echo "  Deployment Complete!"
echo "============================================"

# Get outputs
EIP=$(aws cloudformation describe-stacks \
  --stack-name "${ENV_NAME}-compute" \
  --query "Stacks[0].Outputs[?OutputKey=='ElasticIP'].OutputValue" \
  --output text --region "$REGION" 2>/dev/null || echo "N/A")

INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name "${ENV_NAME}-compute" \
  --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" \
  --output text --region "$REGION" 2>/dev/null || echo "N/A")

SSM_CMD=$(aws cloudformation describe-stacks \
  --stack-name "${ENV_NAME}-compute" \
  --query "Stacks[0].Outputs[?OutputKey=='SSMConnectCommand'].OutputValue" \
  --output text --region "$REGION" 2>/dev/null || echo "N/A")

echo ""
log "Elastic IP:  ${EIP}"
log "Instance ID: ${INSTANCE_ID}"
log "Connect:     ${SSM_CMD}"
echo ""
info "Next steps:"
echo "  1. Connect via SSM:  ${SSM_CMD}"
echo "  2. Configure OpenClaw:"
echo "     cd /opt/openclaw/docker"
echo "     docker compose exec openclaw-gateway bash"
echo "     openclaw onboard"
echo "  3. Check logs:  docker compose logs -f"
echo ""
