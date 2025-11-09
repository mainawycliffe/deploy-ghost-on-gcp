.PHONY: help setup deploy logs plan destroy cleanup

help:
	@echo "Ghost CMS on GCP"
	@echo ""
	@echo "  make setup     - Initial setup and deploy"
	@echo "  make deploy    - Build and deploy updates"
	@echo "  make logs      - View recent logs"
	@echo "  make plan      - Preview Terraform changes"
	@echo "  make destroy   - Remove all resources"
	@echo "  make cleanup   - Destroy resources and wipe state for fresh deployment"

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

cleanup:
	@echo "Destroying all resources and cleaning up state..."
	@cd terraform && terraform destroy -auto-approve || true
	@echo "Removing Terraform state files..."
	@rm -rf terraform/.terraform terraform/.terraform.lock.hcl terraform/terraform.tfstate* terraform/tfplan terraform/terraform.tfvars
	@echo "✓ Cleanup complete! Ready for fresh deployment with 'make setup'"
