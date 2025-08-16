# Makefile for SmartRent Deploy
# Provides common operations for managing the deployment

.PHONY: help setup lint template apply-dev clean

# Default target
help: ## Show this help message
	@echo SmartRent Deploy - Available Commands:
	@echo.
	@echo   help                Show this help message
	@echo   setup               Setup environment (Linux/macOS only)
	@echo   lint                Lint the Helm chart
	@echo   template            Generate Kubernetes manifests from Helm chart
	@echo   template-prod       Generate Kubernetes manifests for production
	@echo   apply-dev           Apply the dev ArgoCD application
	@echo   apply-sealed        Apply sealed secrets for dev environment
	@echo   sync-dev            Force sync the dev ArgoCD application
	@echo   status              Check status of deployments
	@echo   logs-ai             Show AI service logs
	@echo   logs-backend        Show backend service logs
	@echo   secret-list         List sealed secrets for dev environment
	@echo   create-secret       Create a new secret
	@echo   update-secret       Update an existing secret
	@echo   clean               Clean up temporary files
	@echo.
	@echo Examples:
	@echo   make lint
	@echo   make create-secret NAME=API_KEY VALUE=abc123
	@echo   make secret-list

setup: ## Setup environment
	@echo "Setting up environment..."
	@./scripts/setup.sh

lint: ## Lint the Helm chart
	@echo "Linting Helm chart..."
	@helm lint charts/smartrent/

template: ## Generate Kubernetes manifests from Helm chart
	@echo "Generating manifests for dev environment..."
	@helm template charts/smartrent/ --values charts/smartrent/environments/dev/values.yaml

template-prod: ## Generate Kubernetes manifests for production (when available)
	@echo "Generating manifests for production environment..."
	@helm template charts/smartrent/ --values charts/smartrent/environments/prod/values.yaml

apply-dev: ## Apply the dev ArgoCD application
	@echo "Applying dev environment..."
	@kubectl apply -f apps/dev-application.yaml

apply-sealed-secrets: ## Apply sealed secrets for dev environment
	@echo "Applying sealed secrets for dev environment..."
	@kubectl apply -f charts/smartrent/environments/dev/sealed-secrets.yaml

sync-dev: ## Force sync the dev ArgoCD application
	@echo "Syncing dev application in ArgoCD..."
	@kubectl patch application smartrent-dev -n argocd --type merge --patch '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'

status: ## Check status of deployments
	@echo "Checking deployment status..."
	@echo "ArgoCD Applications:"
	@kubectl get applications -n argocd
	@echo ""
	@echo "Dev Environment Pods:"
	@kubectl get pods -n dev
	@echo ""
	@echo "Sealed Secrets:"
	@kubectl get sealedsecrets -n dev

logs-ai: ## Show AI service logs
	@echo "📝 AI Service logs:"
	@kubectl logs -n dev -l app=ai-server --tail=50

logs-backend: ## Show backend service logs
	@echo "📝 Backend Service logs:"
	@kubectl logs -n dev -l app=backend-server --tail=50

secret-list: ## List sealed secrets for dev environment
	@./scripts/manage-secrets dev list

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
	@./scripts/manage-secrets dev create "$(NAME)" "$(VALUE)"

update-secret: ## Update an existing secret (usage: make update-secret NAME=MYSQL_PASSWORD VALUE=newpassword)
ifndef NAME
	@echo "❌ Error: NAME is required. Usage: make update-secret NAME=SECRET_NAME VALUE=secret_value"
	@exit 1
endif
ifndef VALUE
	@echo "❌ Error: VALUE is required. Usage: make update-secret NAME=SECRET_NAME VALUE=secret_value"
	@exit 1
endif
	@./scripts/manage-secrets dev update "$(NAME)" "$(VALUE)"
