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
    "GHOST_URL"
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

# Get Artifact Registry repository URL from Terraform output
cd terraform
ARTIFACT_REGISTRY_URL=$(terraform output -raw artifact_registry_url 2>/dev/null || echo "")
cd ..

if [ -z "$ARTIFACT_REGISTRY_URL" ]; then
    echo -e "${RED}Error: Could not get Artifact Registry URL from Terraform${NC}"
    echo "Please run: cd terraform && terraform apply"
    exit 1
fi

IMAGE_NAME="${ARTIFACT_REGISTRY_URL}/ghost-cms"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t "$FULL_IMAGE_NAME" .

echo -e "${YELLOW}Configuring Docker authentication for Artifact Registry...${NC}"
gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet

echo -e "${YELLOW}Pushing image to Artifact Registry...${NC}"
docker push "$FULL_IMAGE_NAME"

echo -e "${YELLOW}Deploying to Cloud Run...${NC}"
cd terraform
terraform apply -auto-approve -target=google_cloud_run_v2_service.ghost
cd ..

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo "Your Ghost blog should be available at:"
cd terraform
terraform output cloud_run_url
cd ..
echo ""
echo "To access the admin panel, go to: ${GHOST_URL}/ghost"
