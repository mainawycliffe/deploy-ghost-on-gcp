# Ghost CMS Deployment Script (Windows PowerShell)
$ErrorActionPreference = "Stop"

Write-Host "Ghost CMS Deployment Script" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

# Load environment variables
if (-Not (Test-Path ".env")) {
    Write-Host "Error: .env file not found" -ForegroundColor Red
    Write-Host "Please copy .env.example to .env and fill in your values"
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

# Check required variables
$requiredVars = @("GCP_PROJECT_ID", "GCP_REGION")
foreach ($var in $requiredVars) {
    if (-Not (Test-Path "env:$var")) {
        Write-Host "Error: $var is not set in .env" -ForegroundColor Red
        exit 1
    }
}

# Set GCP project
Write-Host "Setting GCP project to: $env:GCP_PROJECT_ID" -ForegroundColor Yellow
gcloud config set project $env:GCP_PROJECT_ID

# Get Artifact Registry repository URL from Terraform output
Set-Location terraform
$artifactRegistryUrl = terraform output -raw artifact_registry_url 2>$null
Set-Location ..

if (-Not $artifactRegistryUrl) {
    Write-Host "Error: Could not get Artifact Registry URL from Terraform" -ForegroundColor Red
    Write-Host "Please run: cd terraform; terraform apply"
    exit 1
}

$imageTag = if ($env:IMAGE_TAG) { $env:IMAGE_TAG } else { "latest" }
$fullImageName = "$artifactRegistryUrl/ghost-cms:$imageTag"

Write-Host "Building Docker image..." -ForegroundColor Yellow
docker build -t $fullImageName .

Write-Host "Configuring Docker authentication for Artifact Registry..." -ForegroundColor Yellow
gcloud auth configure-docker "$env:GCP_REGION-docker.pkg.dev" --quiet

Write-Host "Pushing image to Artifact Registry..." -ForegroundColor Yellow
docker push $fullImageName

Write-Host "Deploying to Cloud Run..." -ForegroundColor Yellow
Set-Location terraform
terraform apply -auto-approve -target=google_cloud_run_v2_service.ghost
Set-Location ..

Write-Host ""
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Your Ghost blog is available at:"
Set-Location terraform
$cloudRunUrl = terraform output -raw cloud_run_url 2>$null
Write-Host $cloudRunUrl
Set-Location ..
Write-Host ""
if ($env:GHOST_URL) {
    Write-Host "Admin panel: $env:GHOST_URL/ghost"
} else {
    Write-Host "Admin panel: $cloudRunUrl/ghost"
}
