# 👻 Deploy Ghost CMS on Google Cloud Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![Ghost](https://img.shields.io/badge/Ghost-5.x-738A94?logo=ghost)](https://ghost.org/)
[![GCP](https://img.shields.io/badge/GCP-Cloud%20Run-4285F4?logo=google-cloud)](https://cloud.google.com/run)

Deploy a self-hosted Ghost CMS on GCP with serverless architecture. Scales to zero, costs ~$20-30/month for low traffic blogs.

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Internet Users                           │
└──────────────────────────┬───────────────────────────────────────┘
                           │ HTTPS
                           ▼
                ┌──────────────────────────┐
                │  Cloud CDN (optional)    │  (enabled by default)
                │  • Global cache          │
                │  • Static content        │
                │  • DDoS protection       │
                └────────────┬─────────────┘
                             │
                             ▼
                ┌──────────────────────────┐
                │  Load Balancer           │
                │  • HTTPS/HTTP            │
                │  • SSL managed           │
                │  • Health check          │
                └────────────┬─────────────┘
                             │
                             ▼
                  ┌────────────────────┐
                  │ Cloud Run (Ghost)  │
                  │ • Serverless       │
                  │ • Scales to zero   │
                  │ • Port 2368        │
                  └─────┬──────┬───────┘
                        │      │
      ┌─────────────────┘      └─────────────────┐
      │                                          │
      ▼                                          ▼
┌──────────────┐                      ┌──────────────────┐
│ Cloud SQL    │                      │ Cloud Storage    │
│ • MySQL 8.0  │                      │ (GCS)            │
│ • Private IP │                      │ • Images         │
│ • Automated  │                      │ • Files          │
│   backups    │                      │ • Public read    │
└──────────────┘                      └──────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                     Supporting Services                           │
├──────────────────────────────────────────────────────────────────┤
│  • Artifact Registry: Docker images                              │
│  • Secret Manager: Database password                             │
│  • Cloud Build: Automated image builds                           │
│  • Service Account: Least-privilege IAM                          │
└──────────────────────────────────────────────────────────────────┘
```

### Components

- **Cloud CDN** (optional): Global edge caching for static content, DDoS protection
- **Load Balancer**: HTTP/HTTPS traffic distribution with managed SSL
- **Cloud Run**: Serverless Ghost container (scales to zero, 0-10 instances)
- **Cloud SQL**: MySQL 8.0 database with automated backups
- **Cloud Storage**: Images and file storage with GCS adapter
- **Artifact Registry**: Private Docker registry for Ghost images
- **Secret Manager**: Secure credential storage
- **Cloud Build**: Automated Docker image builds from source

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

# 2. Edit .env - only GCP_PROJECT_ID is required!
nano .env  # Set GCP_PROJECT_ID (leave GHOST_URL empty for now)

# 3. Deploy
make setup
# Or for bash: chmod +x setup.sh deploy.sh && ./setup.sh
# Or for Windows: .\setup.ps1
```

### Windows Users

If you don't have `make` or `bash`, use the PowerShell scripts:

```powershell
.\setup.ps1   # Initial setup
.\deploy.ps1  # Deploy updates
```

Alternatively, install [Git Bash](https://git-scm.com/downloads) or [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) to use the bash scripts and Makefile.

### After First Deployment

1. **Copy the Cloud Run URL** from the output (e.g., `https://ghost-cms-xxxxx.run.app`)
2. **Update .env** with the actual URL:
   ```bash
   GHOST_URL=https://ghost-cms-xxxxx.run.app
   ```
3. **Redeploy** to update Ghost with correct URL:
   ```bash
   make deploy
   ```
4. **Setup Ghost**: Visit `/ghost` to create your admin account
5. **(Optional)** Map a custom domain later

## ⚙️ Configuration

### Required Settings

Edit `.env` with minimal configuration:

```bash
GCP_PROJECT_ID=your-project-id
GCP_REGION=us-central1  # or your preferred region

# Leave GHOST_URL empty on first deployment
GHOST_URL=
```

**Important**: Leave `GHOST_URL` empty initially. After deployment, update it with the actual Cloud Run URL and redeploy.

### Optional Settings

```bash
# Resource naming (useful for multiple deployments or custom branding)
SERVICE_NAME=ghost-cms  # Must be lowercase, letters/numbers/hyphens only

# Custom domain
GHOST_URL=https://blog.yourdomain.com

# Email configuration
MAIL_FROM='"Your Blog" <noreply@yourdomain.com>'

# Instance sizing
DATABASE_TIER=db-f1-micro          # db-g1-small for production
CLOUD_RUN_MIN_INSTANCES=0          # Set to 1 to avoid cold starts
CLOUD_RUN_MAX_INSTANCES=10

# Cloud CDN (optional, enabled by default)
ENABLE_CDN=true                    # Set to false to disable CDN and use Cloud Run URL directly

# Database protection
DELETION_PROTECTION=true           # Set to false for testing/development to allow easy cleanup
```

## 💵 Costs

**Low traffic blog (~1000 views/month)**: **$20-30/month** (CDN disabled) or **$22-32/month** (CDN enabled)

| Service       | Configuration     | Cost/month |
| ------------- | ----------------- | ---------- |
| Cloud SQL     | db-f1-micro       | $15-20     |
| Cloud Run     | Scales to zero    | $0-5       |
| Cloud Storage | ~5GB              | ~$0.50     |
| Cloud CDN     | ~100GB cache hits | $1-2       |
| Networking    | Minimal egress    | $1-3       |

**Production (10k+ views/month)**: **$60-80/month** (with CDN)

- Upgrade to `db-g1-small` (~$50/month)
- Set `CLOUD_RUN_MIN_INSTANCES=1` (~$10/month)
- Cloud CDN ~$2-3/month with high traffic

**Cloud CDN Benefits**:

- Minimal cost increase (~$1-2/month for low traffic)
- Global edge caching reduces latency
- DDoS protection included
- Caches static assets (images, CSS, JS) with 7-day default TTL
- Aggressive caching policy (30-day max) minimizes origin requests
- Health checks only every 30 seconds to reduce costs
- Disable if not needed with `ENABLE_CDN=false`

**Cost Optimization**:

- Static content cached for up to 30 days (vs 1 hour previously)
- 24-hour client-side caching reduces repeat downloads
- Aggressive negative caching prevents repeated 404 checks
- Health check frequency optimized for cost vs reliability

## 🌐 Custom Domain Setup

### Without Cloud CDN

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

### With Cloud CDN (Enabled by Default)

When `ENABLE_CDN=true` (default), point your domain to the load balancer IP:

```bash
# Get the CDN load balancer IP after deployment
cd terraform && terraform output cdn_ip_address

# Add an A record in your DNS registrar pointing to this IP
# Example: blog.yourdomain.com -> 203.0.113.45
```

Then update `GHOST_URL` in `.env` and redeploy:

```bash
GHOST_URL=https://blog.yourdomain.com
make deploy
```

**Note**: When using Cloud CDN, your domain must be set in `GHOST_URL` before deployment for SSL certificate provisioning.

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
