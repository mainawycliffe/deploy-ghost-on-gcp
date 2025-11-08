# 👻 Deploy Ghost CMS on Google Cloud Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![Ghost](https://img.shields.io/badge/Ghost-5.x-738A94?logo=ghost)](https://ghost.org/)
[![GCP](https://img.shields.io/badge/GCP-Cloud%20Run-4285F4?logo=google-cloud)](https://cloud.google.com/run)

Deploy a self-hosted Ghost CMS on GCP with serverless architecture. Scales to zero, costs ~$20-30/month for low traffic blogs.

## 🏗️ Architecture

- **Cloud Run**: Serverless Ghost container (scales to zero)
- **Cloud SQL**: MySQL 8.0 database
- **Cloud Storage**: Images and file storage
- **Artifact Registry**: Private Docker registry
- **Secret Manager**: Secure credential storage

## 🚀 Quick Start

### Prerequisites

- GCP account with billing enabled
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://www.terraform.io/downloads) (>= 1.0)

### Deploy in 3 Steps

```bash
# 1. Clone and configure
git clone https://github.com/YOUR_USERNAME/deploy-ghost-on-gcp.git
cd deploy-ghost-on-gcp
cp .env.example .env

# 2. Edit .env with your configuration
nano .env  # Set GCP_PROJECT_ID and GHOST_URL

# 3. Deploy
make setup
# Or for bash: chmod +x setup.sh deploy.sh && ./setup.sh
# Or for Windows: .\setup.ps1
```

That's it! Your Ghost blog will be running on Cloud Run.

### Windows Users

If you don't have `make` or `bash`, use the PowerShell scripts:

```powershell
.\setup.ps1   # Initial setup
.\deploy.ps1  # Deploy updates
```

Alternatively, install [Git Bash](https://git-scm.com/downloads) or [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) to use the bash scripts and Makefile.

### After Deployment

1. Visit the Cloud Run URL shown in the output
2. Go to `/ghost` to create your admin account
3. (Optional) Map a custom domain following the instructions below

## ⚙️ Configuration

### Required Settings

Edit `.env` and set:

```bash
GCP_PROJECT_ID=your-project-id
GCP_REGION=us-central1  # or your preferred region

# Ghost URL - use a placeholder initially, update after deployment
GHOST_URL=https://ghost-cms-PROJECT_ID.run.app
```

**Note**: Set `GHOST_URL` to your intended domain, or use a placeholder Cloud Run URL format. After deployment, you'll get the actual URL and can update it.

### Optional Settings

```bash
# Custom domain
GHOST_URL=https://blog.yourdomain.com

# Email configuration
MAIL_FROM='"Your Blog" <noreply@yourdomain.com>'

# Instance sizing
DATABASE_TIER=db-f1-micro          # db-g1-small for production
CLOUD_RUN_MIN_INSTANCES=0          # Set to 1 to avoid cold starts
CLOUD_RUN_MAX_INSTANCES=10
```

## 💵 Costs

**Low traffic blog (~1000 views/month)**: **$20-30/month**

| Service       | Configuration      | Cost/month |
| ------------- | ------------------ | ---------- |
| Cloud SQL     | db-f1-micro        | $15-20     |
| Cloud Run     | Scales to zero     | $0-5       |
| Cloud Storage | ~5GB               | ~$0.50     |
| Networking    | Minimal egress     | $1-3       |

**Production (10k+ views/month)**: **$60-80/month**
- Upgrade to `db-g1-small` (~$50/month)
- Set `CLOUD_RUN_MIN_INSTANCES=1` (~$10/month)

## 🌐 Custom Domain Setup

After deployment, map your domain:

```bash
# Create domain mapping
gcloud run domain-mappings create \
  --service ghost-cms \
  --domain blog.yourdomain.com \
  --region us-central1

# Add the DNS records shown in output to your domain registrar
```

Update `GHOST_URL` in `.env` and redeploy:

```bash
make deploy
```

## 🔧 Common Operations

### View Logs

```bash
make logs
# Or: gcloud run services logs tail ghost-cms --project=your-project-id --region=us-central1
```

### Update Ghost

```bash
make deploy  # Pulls latest Ghost 5.x
```

### Manual Backup

```bash
gcloud sql backups create \
  --instance=$(cd terraform && terraform output -raw database_instance_name)
```

### Scale Up

Edit `terraform/terraform.tfvars`:

```hcl
database_tier = "db-g1-small"
cloud_run_max_instances = 20
```

Apply changes:

```bash
make plan   # Preview changes
make apply  # Apply changes
```

## 🐛 Troubleshooting

### Container Fails to Start

```bash
# Check logs
gcloud run services logs read ghost-cms --limit=50

# Common fix: increase memory in terraform/main.tf
# Change memory = "1Gi" to memory = "2Gi"
```

### Images Not Uploading

```bash
# Verify bucket permissions
gcloud storage buckets get-iam-policy gs://$(cd terraform && terraform output -raw bucket_name)

# Should show service account with storage.objectAdmin role
```

### Slow First Load (Cold Start)

Set minimum instances to 1:

```bash
# Edit terraform/terraform.tfvars
cloud_run_min_instances = 1

make apply
```

**Note**: This increases costs (~$10/month) but eliminates cold starts.

## 📧 Email Configuration

Ghost uses direct mail by default. For production, configure SMTP by adding to `config.production.json`:

```json
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

Then redeploy with `make deploy`.

## 🗑️ Cleanup

Remove all resources:

```bash
make destroy
```

**Warning**: This permanently deletes your database and all content.

## 🛡️ Security Notes

- Cloud SQL has no public IP (private connection only)
- Database password stored in Secret Manager
- Service account with minimal permissions
- Deletion protection enabled on database by default

## 📂 Project Structure

```
deploy-ghost-on-gcp/
├── Dockerfile                   # Multi-stage Ghost + GCS adapter
├── Makefile                     # Common commands (Mac/Linux)
├── setup.sh / setup.ps1         # Setup scripts (bash/PowerShell)
├── deploy.sh / deploy.ps1       # Deploy scripts (bash/PowerShell)
├── docker-entrypoint.sh         # Container startup script
├── config.production.json       # Ghost configuration
├── .env.example                 # Configuration template
└── terraform/
    ├── main.tf                  # Infrastructure definition
    └── terraform.tfvars.example # Variables template
```

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## 📝 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- [Ghost CMS](https://ghost.org/)
- [ghost-gcs-adapter](https://github.com/danmasta/ghost-gcs-adapter)

---

**Need help?** [Open an issue](https://github.com/YOUR_USERNAME/deploy-ghost-on-gcp/issues)
