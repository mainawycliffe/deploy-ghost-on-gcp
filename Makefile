.PHONY: help setup deploy logs plan destroy

help:
	@echo "Ghost CMS on GCP"
	@echo ""
	@echo "  make setup     - Initial setup and deploy"
	@echo "  make deploy    - Build and deploy updates"
	@echo "  make logs      - View recent logs"
	@echo "  make plan      - Preview Terraform changes"
	@echo "  make destroy   - Remove all resources"

setup:
	@./setup.sh

deploy:
	@./deploy.sh

logs:
	@. ./.env && gcloud run services logs tail ghost-cms \
		--project=$${GCP_PROJECT_ID} \
		--region=$${GCP_REGION}

plan:
	@cd terraform && terraform plan

destroy:
	@cd terraform && terraform destroy
