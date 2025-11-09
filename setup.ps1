# Ghost CMS Infrastructure Setup (Windows PowerShell)
$ErrorActionPreference = "Stop"

Write-Host "Ghost CMS Infrastructure Setup" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""

# Load environment variables
if (-Not (Test-Path ".env")) {
    Write-Host "Warning: .env file not found" -ForegroundColor Yellow
    Write-Host "Creating from .env.example..."
    Copy-Item .env.example .env
    Write-Host "Please edit .env with your values and run this script again" -ForegroundColor Red
    exit 1
}

# Load .env file
Get-Content .env | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $key = $matches[1]
        $value = $matches[2] -replace '^[''"]|[''"]$', ''
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

# Check required tools
Write-Host "Checking required tools..." -ForegroundColor Blue

if (-Not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Host "Error: gcloud CLI is not installed" -ForegroundColor Red
    Write-Host "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
}

if (-Not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Terraform is not installed" -ForegroundColor Red
    Write-Host "Install from: https://www.terraform.io/downloads"
    exit 1
}

if (-Not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Docker is not installed" -ForegroundColor Red
    Write-Host "Install from: https://docs.docker.com/get-docker/"
    exit 1
}

Write-Host "✓ All required tools are installed" -ForegroundColor Green
Write-Host ""

# Authenticate with GCP
Write-Host "Authenticating with GCP..." -ForegroundColor Blue
gcloud auth login
gcloud config set project $env:GCP_PROJECT_ID

Write-Host "✓ Authenticated with GCP" -ForegroundColor Green
Write-Host ""

# Create terraform.tfvars
Write-Host "Creating Terraform configuration..." -ForegroundColor Blue
Set-Location terraform

if (-Not (Test-Path "terraform.tfvars")) {
    $ghostUrl = if ($env:GHOST_URL) { $env:GHOST_URL } else { "" }
    $serviceName = if ($env:SERVICE_NAME) { $env:SERVICE_NAME } else { "ghost-cms" }
    $deletionProtection = if ($env:DELETION_PROTECTION) { $env:DELETION_PROTECTION } else { "false" }
    @"
project_id   = "$env:GCP_PROJECT_ID"
region       = "$env:GCP_REGION"
service_name = "$serviceName"
ghost_url    = "$ghostUrl"
mail_from    = $env:MAIL_FROM

database_tier           = "$env:DATABASE_TIER"
cloud_run_min_instances = $env:CLOUD_RUN_MIN_INSTANCES
cloud_run_max_instances = $env:CLOUD_RUN_MAX_INSTANCES
deletion_protection     = $deletionProtection
"@ | Out-File -FilePath "terraform.tfvars" -Encoding UTF8
    Write-Host "✓ Created terraform.tfvars" -ForegroundColor Green
} else {
    Write-Host "terraform.tfvars already exists, skipping..." -ForegroundColor Yellow
}

# Initialize Terraform
Write-Host "Initializing Terraform..." -ForegroundColor Blue
terraform init

Write-Host "✓ Terraform initialized" -ForegroundColor Green
Write-Host ""

# Plan infrastructure
Write-Host "Planning infrastructure..." -ForegroundColor Blue
terraform plan -out=tfplan

Write-Host ""
Write-Host "Ready to create infrastructure!" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will create:"
Write-Host "  - Cloud SQL MySQL instance ($env:DATABASE_TIER)"
Write-Host "  - Cloud Storage bucket for Ghost content"
Write-Host "  - Cloud Run service for Ghost CMS"
Write-Host "  - Artifact Registry repository for Docker images"
Write-Host "  - Service account with necessary permissions"
Write-Host "  - Secret Manager secret for database password"
Write-Host ""
$confirmation = Read-Host "Do you want to proceed? (yes/no)"

if ($confirmation -ne "yes") {
    Write-Host "Aborted" -ForegroundColor Red
    exit 1
}

# Apply infrastructure (except Cloud Run service)
Write-Host "Creating infrastructure (database, storage, etc.)..." -ForegroundColor Blue
terraform apply -auto-approve `
  -target=google_project_service.required_apis `
  -target=google_service_account.ghost_sa `
  -target=google_storage_bucket.ghost_content `
  -target=google_storage_bucket_iam_member.public_read `
  -target=google_storage_bucket_iam_member.ghost_storage_admin `
  -target=google_project_iam_member.ghost_cloudsql_client `
  -target=google_secret_manager_secret.db_password `
  -target=google_secret_manager_secret_version.db_password_version `
  -target=google_secret_manager_secret_iam_member.ghost_secret_accessor `
  -target=google_artifact_registry_repository.ghost_repo `
  -target=google_sql_database_instance.ghost_db `
  -target=google_sql_database.ghost_database `
  -target=google_sql_user.ghost_user `
  -target=random_id.suffix `
  -target=random_password.db_password

Write-Host "✓ Infrastructure created successfully!" -ForegroundColor Green
Write-Host ""

Set-Location ..

# Build and push Docker image
Write-Host "Building and pushing Docker image..." -ForegroundColor Blue
Set-Location terraform
$artifactRegistryUrl = terraform output -raw artifact_registry_url
Set-Location ..
$imageName = "$artifactRegistryUrl/ghost-cms:latest"

Write-Host "Building image: $imageName" -ForegroundColor Yellow
docker build -t $imageName .

Write-Host "Configuring Docker authentication..." -ForegroundColor Yellow
gcloud auth configure-docker "$env:GCP_REGION-docker.pkg.dev" --quiet

Write-Host "Pushing image to Artifact Registry..." -ForegroundColor Yellow
docker push $imageName

Write-Host "✓ Docker image built and pushed!" -ForegroundColor Green
Write-Host ""

# Deploy Cloud Run service
Write-Host "Deploying Ghost to Cloud Run..." -ForegroundColor Blue
Set-Location terraform
terraform apply -auto-approve

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Map your custom domain to the Cloud Run service URL"
Write-Host "2. Visit your Ghost admin panel at: $env:GHOST_URL/ghost"
Write-Host "3. Complete the Ghost setup wizard"
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  - View logs: gcloud run services logs read ghost-cms --project=$env:GCP_PROJECT_ID"
Write-Host "  - Redeploy: .\deploy.ps1"
Write-Host "  - Destroy infrastructure: cd terraform; terraform destroy"
