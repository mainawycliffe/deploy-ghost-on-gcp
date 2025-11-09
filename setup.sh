#!/bin/bash
set -e

# Use Homebrew paths for tools
export PATH="/opt/homebrew/bin:$PATH"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Ghost CMS Infrastructure Setup${NC}"
echo "======================================="
echo ""

# Load environment variables if they exist
if [ -f .env ]; then
    source .env
else
    echo -e "${YELLOW}Warning: .env file not found${NC}"
    echo "Creating from .env.example..."
    cp .env.example .env
    echo -e "${RED}Please edit .env with your values and run this script again${NC}"
    exit 1
fi

# Check if required tools are installed
echo -e "${BLUE}Checking required tools...${NC}"

command -v gcloud >/dev/null 2>&1 || {
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
}

command -v terraform >/dev/null 2>&1 || {
    echo -e "${RED}Error: Terraform is not installed${NC}"
    echo "Install from: https://www.terraform.io/downloads"
    exit 1
}

# Check Docker with full path as it might not be in PATH
if ! command -v docker >/dev/null 2>&1 && ! /usr/local/bin/docker --version >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Install from: https://docs.docker.com/get-docker/"
    exit 1
fi

echo -e "${GREEN}✓ All required tools are installed${NC}"
echo ""

# Authenticate with GCP
echo -e "${BLUE}Authenticating with GCP...${NC}"
gcloud auth login
gcloud config set project "$GCP_PROJECT_ID"

echo -e "${GREEN}✓ Authenticated with GCP${NC}"
echo ""

# Create terraform.tfvars from template
echo -e "${BLUE}Creating Terraform configuration...${NC}"
cd terraform

if [ ! -f terraform.tfvars ]; then
    GHOST_URL_VALUE="${GHOST_URL:-}"
    SERVICE_NAME_VALUE="${SERVICE_NAME:-ghost-cms}"
    cat > terraform.tfvars <<EOF
project_id   = "$GCP_PROJECT_ID"
region       = "$GCP_REGION"
service_name = "$SERVICE_NAME_VALUE"
ghost_url    = "$GHOST_URL_VALUE"
mail_from    = "\"Ghost Test\" <noreply@example.com>"

database_tier           = "$DATABASE_TIER"
cloud_run_min_instances = $CLOUD_RUN_MIN_INSTANCES
cloud_run_max_instances = $CLOUD_RUN_MAX_INSTANCES
EOF
    echo -e "${GREEN}✓ Created terraform.tfvars${NC}"
else
    echo -e "${YELLOW}terraform.tfvars already exists, skipping...${NC}"
fi

# Initialize Terraform
echo -e "${BLUE}Initializing Terraform...${NC}"
terraform init

echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Plan infrastructure
echo -e "${BLUE}Planning infrastructure...${NC}"
terraform plan -out=tfplan

echo ""
echo -e "${YELLOW}Ready to create infrastructure!${NC}"
echo ""
echo "This will create:"
echo "  - Cloud SQL MySQL instance (${DATABASE_TIER})"
echo "  - Cloud Storage bucket for Ghost content"
echo "  - Cloud Run service for Ghost CMS"
echo "  - Artifact Registry repository for Docker images"
echo "  - Service account with necessary permissions"
echo "  - Secret Manager secret for database password"
echo ""
read -p "Do you want to proceed? (yes/no) " -n 3 -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${RED}Aborted${NC}"
    exit 1
fi

# Apply infrastructure
echo -e "${BLUE}Creating infrastructure and deploying Ghost...${NC}"
echo -e "${YELLOW}This will take 10-15 minutes (Cloud SQL provisioning is slow)${NC}"
terraform apply tfplan

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Your Ghost CMS is deployed!${NC}"
echo ""
CLOUD_RUN_URL=$(terraform output -raw cloud_run_url 2>/dev/null || echo "Check Cloud Run console")
echo -e "${YELLOW}Cloud Run URL: $CLOUD_RUN_URL${NC}"
echo ""
echo -e "${BLUE}IMPORTANT - Next Steps:${NC}"
echo "1. Update .env with the Cloud Run URL above:"
echo "   GHOST_URL=$CLOUD_RUN_URL"
echo ""
echo "2. Redeploy to update Ghost configuration:"
echo "   make deploy"
echo ""
echo "3. Then visit: $CLOUD_RUN_URL/ghost to setup your account"
echo ""
echo "Useful commands:"
echo "  - View logs: make logs"
echo "  - Redeploy: make deploy"
echo "  - Destroy: make destroy"
