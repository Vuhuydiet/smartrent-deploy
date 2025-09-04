# Makefile for SmartRent Deploy
# Provides common operations for managing the deployment

.PHONY: help setup lint template apply-dev clean

setup: ## Setup environment
	@echo "Setting up environment..."
	@./scripts/setup.sh

lint: ## Lint the Helm chart
	@echo "Linting Helm chart..."
	@helm lint charts/smartrent/

template: ## Generate Kubernetes manifests from Helm chart
	@echo "Generating manifests for dev environment..."
	@helm template charts/smartrent/ --values charts/smartrent/environments/dev/values.yaml

apply-sealed-secrets: ## Apply sealed secrets for dev environment
	@echo "Applying sealed secrets for dev environment..."
	@kubectl apply -f charts/smartrent/environments/dev/sealed-secrets.yaml

sync-dev: ## Force sync the dev ArgoCD application
	@echo "Syncing dev application in ArgoCD..."
	@kubectl patch application smartrent-dev -n argocd --type merge --patch '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'

secret-list: ## List sealed secrets for dev environment
	@./scripts/manage-secrets.sh dev list

clean: ## Clean up temporary files
	@echo "🧹 Cleaning up..."
	@rm -f temp-secret.yaml
	@echo "✅ Cleanup complete"

# Secret management shortcuts
create-secret: ## Create a new secret (usage: make create-secret NAME=MYSQL_PASSWORD VALUE=mypassword)
ifndef NAME
	@echo "❌ Error: NAME is required. Usage: make create-secret NAME=SECRET_NAME VALUE=secret_value"
	@exit 1
endif
ifndef VALUE
	@echo "❌ Error: VALUE is required. Usage: make create-secret NAME=SECRET_NAME VALUE=secret_value"
	@exit 1
endif
	@./scripts/manage-secrets.sh dev create "$(NAME)" "$(VALUE)"

update-secret: ## Update an existing secret (usage: make update-secret NAME=MYSQL_PASSWORD VALUE=newpassword)
ifndef NAME
	@echo "❌ Error: NAME is required. Usage: make update-secret NAME=SECRET_NAME VALUE=secret_value"
	@exit 1
endif
ifndef VALUE
	@echo "❌ Error: VALUE is required. Usage: make update-secret NAME=SECRET_NAME VALUE=secret_value"
	@exit 1
endif
	@./scripts/manage-secrets.sh dev update "$(NAME)" "$(VALUE)"
