# 👻 Deploy Ghost CMS on Google Cloud Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![Ghost](https://img.shields.io/badge/Ghost-5.x-738A94?logo=ghost)](https://ghost.org/)
[![GCP](https://img.shields.io/badge/GCP-Cloud%20Run-4285F4?logo=google-cloud)](https://cloud.google.com/run)

Self-hosted Ghost CMS running on Google Cloud Platform with a serverless architecture using Cloud Run, Cloud SQL, and Cloud Storage. This setup provides a scalable, cost-effective solution that can scale to zero when not in use.

## 🏗️ Architecture

```
┌─────────────────┐
│   Custom Domain │
│  (Cloud Run URL)│
└────────┬────────┘
         │
┌────────▼────────────┐
│   Cloud Run         │ ← Ghost CMS (Serverless)
│   (ghost-cms)       │
└────┬────────────┬───┘
     │            │
     │            └────────────────┐
     │                             │
┌────▼──────────────┐   ┌──────────▼──────────┐
│  Cloud SQL        │   │  Cloud Storage      │
│  MySQL 8.0        │   │  (Images & Files)   │
└───────────────────┘   └─────────────────────┘
```

### Components

- **Cloud Run**: Serverless container hosting for Ghost CMS (scales to zero)
- **Cloud SQL**: Managed MySQL database for Ghost content
- **Cloud Storage**: Object storage for images, themes, and uploaded files
- **Artifact Registry**: Private Docker registry for Ghost container images
- **Secret Manager**: Secure storage for database credentials
- **Service Account**: IAM identity with minimal required permissions

## ✨ Features

- 🚀 **One-command deployment** with automated setup scripts
- 💰 **Cost-effective** - scales to zero when not in use (~$20-30/month for low traffic)
- 🔒 **Secure** - No public database IP, secrets in Secret Manager
- 📦 **Infrastructure as Code** - Fully managed with Terraform
- 🌍 **Global CDN** - Serve content from Cloud Storage with low latency
- 🔄 **Multi-stage Docker build** - Optimized container images
- 📊 **Automatic backups** - Daily database backups included
- 🎨 **Full Ghost features** - Themes, newsletters, memberships, etc.

## 📋 Prerequisites

Before you begin, ensure you have:

1. **Google Cloud Platform Account**
   - Active GCP project with billing enabled
   - Project ID ready

2. **Required Tools**
   - [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install)
   - [Terraform](https://www.terraform.io/downloads) (>= 1.0)
   - [Docker](https://docs.docker.com/get-docker/)

3. **Permissions**
   - Owner or Editor role on the GCP project
   - Ability to enable APIs and create resources

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/deploy-ghost-on-gcp.git
cd deploy-ghost-on-gcp
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your values
nano .env
```

**Required Configuration:**

```bash
GCP_PROJECT_ID=your-project-id
GCP_REGION=us-central1
GHOST_URL=https://blog.yourdomain.com
MAIL_FROM='"Your Blog Name" <noreply@yourdomain.com>'
```

### 3. Run Setup Script

The setup script will:
- Verify all prerequisites
- Authenticate with GCP
- Initialize Terraform
- Create all infrastructure
- Build and deploy Ghost

```bash
# Make scripts executable
chmod +x setup.sh deploy.sh

# Run setup
./setup.sh
```

Follow the prompts and confirm when asked to create infrastructure.

### 4. Configure Your Domain

After deployment, you'll receive a Cloud Run URL like:
```
https://ghost-cms-xxxxx-uc.a.run.app
```

**To use your custom domain:**

```bash
# Map your domain to Cloud Run
gcloud run domain-mappings create \
  --service ghost-cms \
  --domain blog.yourdomain.com \
  --region us-central1 \
  --project your-project-id
```

Then add the DNS records shown in the output to your domain provider.

### 5. Complete Ghost Setup

1. Visit: `https://blog.yourdomain.com/ghost`
2. Create your admin account
3. Configure your blog settings

## 📂 Project Structure

```
deploy-ghost-on-gcp/
├── Dockerfile                    # Multi-stage Ghost container with GCS adapter
├── docker-entrypoint.sh          # Custom entrypoint for env substitution
├── config.production.json        # Ghost configuration template
├── .env.example                  # Environment variables template
├── setup.sh                      # One-command setup script
├── deploy.sh                     # Deployment script
├── terraform/
│   ├── main.tf                   # Infrastructure as Code
│   ├── terraform.tfvars.example  # Terraform variables template
│   └── .gitignore
├── .gitignore
├── LICENSE
├── CONTRIBUTING.md
└── README.md
```

## ⚙️ Configuration

### Environment Variables

All configuration is managed through environment variables in `.env`:

| Variable                  | Description                       | Default       |
| ------------------------- | --------------------------------- | ------------- |
| `GCP_PROJECT_ID`          | Your GCP project ID               | Required      |
| `GCP_REGION`              | GCP region for resources          | `us-central1` |
| `GHOST_URL`               | Public URL for your blog          | Required      |
| `MAIL_FROM`               | From email address                | Required      |
| `DATABASE_TIER`           | Cloud SQL instance tier           | `db-f1-micro` |
| `CLOUD_RUN_MIN_INSTANCES` | Min instances (0 = scale to zero) | `0`           |
| `CLOUD_RUN_MAX_INSTANCES` | Max instances                     | `10`          |

### Terraform Variables

Configure infrastructure settings in `terraform/terraform.tfvars`:

```hcl
project_id = "your-project-id"
region     = "us-central1"
ghost_url  = "https://blog.yourdomain.com"
mail_from  = "\"Your Blog Name\" <noreply@yourdomain.com>"
database_tier = "db-f1-micro"  # or db-g1-small for production
cloud_run_min_instances = 0    # Set to 1 to avoid cold starts
```

## 💵 Cost Estimation

**Estimated Monthly Costs (Low Traffic Blog):**

| Service       | Configuration             | Monthly Cost |
| ------------- | ------------------------- | ------------ |
| Cloud SQL     | db-f1-micro (shared-core) | ~$15-20      |
| Cloud Run     | Scales to zero            | ~$0-5        |
| Cloud Storage | ~5GB content              | ~$0.10-1     |
| Networking    | Egress & requests         | ~$1-3        |
| **Total**     |                           | **~$20-30**  |

**For Production (Medium Traffic):**

- Cloud SQL: `db-g1-small` (~$50/month)
- Cloud Run: Min instances = 1 (~$10/month)
- **Total: ~$60-80/month**

### Cost Optimization Tips

1. **Scale to Zero**: Keep `CLOUD_RUN_MIN_INSTANCES=0` for low-traffic sites
2. **Right-size Database**: Start with `db-f1-micro`, upgrade if needed
3. **Enable CDN**: Use Cloud CDN for static assets (separate setup)
4. **Monitor Usage**: Set up billing alerts in GCP

## 🛠️ Manual Deployment

If you prefer manual steps or need to troubleshoot:

### Initialize Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply
```

### Build and Deploy Ghost

```bash
cd ..

# Get Artifact Registry URL
REGISTRY=$(cd terraform && terraform output -raw artifact_registry_url)

# Build Docker image
docker build -t ${REGISTRY}/ghost-cms:latest .

# Authenticate Docker with Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Push image
docker push ${REGISTRY}/ghost-cms:latest

# Deploy to Cloud Run
cd terraform
terraform apply -target=google_cloud_run_v2_service.ghost
```

## 🔧 Operations

### View Logs

```bash
# Cloud Run logs
gcloud run services logs read ghost-cms \
  --project=your-project-id \
  --region=us-central1 \
  --limit=50

# Follow logs in real-time
gcloud run services logs tail ghost-cms \
  --project=your-project-id \
  --region=us-central1
```

### Update Ghost

```bash
# Update to latest Ghost version
./deploy.sh
```

The Dockerfile uses `ghost:5-alpine` which pulls the latest Ghost 5.x version.

### Database Backup

Cloud SQL automatically backs up your database daily. To create a manual backup:

```bash
gcloud sql backups create \
  --instance=ghost-db-xxxxx \
  --project=your-project-id
```

### Scale Resources

**Increase Cloud Run capacity:**

```bash
# Edit terraform/terraform.tfvars
cloud_run_max_instances = 20

# Apply changes
cd terraform && terraform apply
```

**Upgrade database:**

```bash
# Edit terraform/terraform.tfvars
database_tier = "db-g1-small"

# Apply changes (may require downtime)
cd terraform && terraform apply
```

## 🐛 Troubleshooting

### Cloud Run Container Crashes

**Symptom**: Service returns 502 or 503 errors

```bash
# Check logs for errors
gcloud run services logs read ghost-cms --limit=100

# Common issues:
# - Database connection: Verify Cloud SQL instance is running
# - Environment variables: Check Secret Manager access
# - Memory: Increase to 1Gi or 2Gi in terraform/main.tf
```

**Fix database connection issues:**
```bash
# Verify Cloud SQL instance is running
gcloud sql instances describe ghost-db-xxxxx

# Test connection from Cloud Shell
gcloud sql connect ghost-db-xxxxx --user=ghost
```

### Upload Issues (Cloud Storage)

**Symptom**: Images fail to upload in Ghost admin

```bash
# Verify bucket permissions
gcloud storage buckets get-iam-policy gs://your-bucket-name

# Check CORS configuration
gcloud storage buckets describe gs://your-bucket-name --format="get(cors)"
```

**Fix**: Ensure the service account has `storage.objectAdmin` role on the bucket.

### Cold Start Performance

**Symptom**: First request after inactivity is slow

If cold starts are too slow, set minimum instances:

```bash
# Edit terraform/terraform.tfvars
cloud_run_min_instances = 1

cd terraform && terraform apply
```

**Note**: This will increase costs but eliminate cold starts.

### Terraform Errors

**Error**: "Error creating Service: googleapi: Error 400: Revision template_name is invalid"

```bash
# Validate Terraform configuration
terraform validate

# Format Terraform files
terraform fmt

# Re-initialize Terraform
terraform init -upgrade
```

## 🔒 Security Best Practices

1. **Enable Cloud Armor** for DDoS protection
2. **Use VPC Connector** for private Cloud SQL connection (optional advanced setup)
3. **Enable Cloud Audit Logs** for compliance
4. **Rotate Secrets** periodically using Secret Manager
5. **Set up IAM Alerts** for suspicious activity
6. **Enable 2FA** on Ghost admin accounts
7. **Disable deletion protection** carefully (enabled by default on Cloud SQL)

## 🗑️ Cleanup

To completely remove all resources:

```bash
cd terraform

# This will destroy all infrastructure
terraform destroy

# Confirm when prompted
```

**Warning**: This will permanently delete:
- Cloud SQL database and all content
- Cloud Storage bucket and all images
- All Ghost configuration

## 📚 Advanced Configuration

### Custom Themes

Upload themes via Ghost admin or use Cloud Storage:

```bash
# Upload theme to Cloud Storage
gsutil cp -r your-theme.zip gs://your-bucket/themes/

# Extract and activate in Ghost admin
```

### Email Configuration

Ghost uses Direct transport by default. For production, configure SMTP:

Add to `config.production.json`:
```javascript
"mail": {
  "transport": "SMTP",
  "options": {
    "service": "Gmail",
    "auth": {
      "user": "your-email@gmail.com",
      "pass": "your-app-password"
    }
  }
}
```

Then add SMTP environment variables to terraform/main.tf or update config dynamically.

### Custom Domain Mapping

After deploying, map your custom domain:

```bash
# Create domain mapping
gcloud run domain-mappings create \
  --service ghost-cms \
  --domain blog.yourdomain.com \
  --region us-central1

# Add DNS records from the output to your domain provider
# Usually a CNAME pointing to ghs.googlehosted.com
```

### CDN Integration

Enable Cloud CDN for better performance:

1. Create a load balancer in front of Cloud Run
2. Configure Cloud CDN on the backend
3. Update `GHOST_URL` to point to CDN domain

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Ghost CMS](https://ghost.org/) - The amazing content management system
- [danmasta/ghost-gcs-adapter](https://github.com/danmasta/ghost-gcs-adapter) - GCS storage adapter for Ghost
- Google Cloud Platform for the infrastructure

## 📞 Support

- **Ghost Documentation**: https://ghost.org/docs/
- **GCP Documentation**: https://cloud.google.com/docs
- **Issues**: [Create an issue](https://github.com/YOUR_USERNAME/deploy-ghost-on-gcp/issues)

---

Made with ❤️ for the Ghost and GCP communities
