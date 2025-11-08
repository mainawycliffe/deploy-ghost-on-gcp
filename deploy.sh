#!/bin/bash
set -e

# Use Homebrew paths for tools
export PATH="/opt/homebrew/bin:$PATH"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Ghost CMS Deployment Script${NC}"
echo "======================================="

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please copy .env.example to .env and fill in your values"
    exit 1
fi

# Check required variables
REQUIRED_VARS=(
    "GCP_PROJECT_ID"
    "GCP_REGION"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}Error: $var is not set in .env${NC}"
        exit 1
    fi
done

# Set GCP project
echo -e "${YELLOW}Setting GCP project to: $GCP_PROJECT_ID${NC}"
gcloud config set project "$GCP_PROJECT_ID"

echo -e "${YELLOW}Building and deploying Ghost...${NC}"
cd terraform
terraform apply -auto-approve
cd ..

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo "Your Ghost blog is available at:"
cd terraform
GHOST_URL_OUTPUT=$(terraform output -raw cloud_run_url 2>/dev/null || echo "")
echo "$GHOST_URL_OUTPUT"
cd ..
echo ""
if [ -n "$GHOST_URL" ]; then
    echo "Admin panel: ${GHOST_URL}/ghost"
else
    echo "Admin panel: ${GHOST_URL_OUTPUT}/ghost"
fi
