#!/bin/bash

# Sealed Secrets Management Script for SmartRent AI
# Usage: ./manage-secrets.sh.sh [environment] [action] [secret-name] [secret-value]

set -e

# Function to display usage
usage() {
    echo "Usage: $0 <environment> <action> [secret-name] [secret-value]"
    echo ""
    echo "Arguments:"
    echo "  environment: dev, staging, prod"
    echo "  action:      create, update, list, delete"
    echo "  secret-name: Name of the secret (required for create/update/delete)"
    echo "  secret-value: Value of the secret (required for create/update)"
    echo ""
    echo "Examples:"
    echo "  $0 dev list"
    echo "  $0 dev create MYSQL_PASSWORD mypassword123"
    echo "  $0 dev update API_KEY new-api-key-value"
    echo "  $0 dev delete OLD_SECRET"
    exit 1
}

# Check arguments
if [ $# -lt 2 ]; then
    usage
fi

ENVIRONMENT=$1
ACTION=$2
SECRET_NAME=$3
SECRET_VALUE=$4

# Validate environment
case $ENVIRONMENT in
    dev|staging|prod)
        ;;
    *)
        echo "Error: Invalid environment. Must be dev, staging, or prod."
        exit 1
        ;;
esac

# Validate action
case $ACTION in
    create|update|list|delete)
        ;;
    *)
        echo "Error: Invalid action. Must be create, update, list, or delete."
        exit 1
        ;;
esac

# Set variables
SECRET_FILE="charts/smartrent/environments/$ENVIRONMENT/sealed-secrets.yaml"
NAMESPACE=$ENVIRONMENT
KUBESEAL_SECRET_NAME="ai-server-secrets"
TEMP_SECRET_FILE="temp-secret.yaml"

# Check if kubeseal is available
if ! command -v kubeseal &> /dev/null; then
    echo "Error: kubeseal is not installed or not in PATH."
    echo "Please install kubeseal: https://github.com/bitnami-labs/sealed-secrets#installation"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH."
    exit 1
fi

# Function to create sealed secret
create_sealed_secret() {
    local name=$1
    local value=$2
    
    echo "Creating sealed secret for $name in $ENVIRONMENT environment..."
    
    # Create temporary secret
    cat > $TEMP_SECRET_FILE << EOF
apiVersion: v1
kind: Secret
metadata:
  name: $KUBESEAL_SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
data:
  $name: $(echo -n "$value" | base64 -w 0)
EOF
    
    # Convert to sealed secret
    kubeseal --format=yaml < $TEMP_SECRET_FILE > $SECRET_FILE
    
    # Clean up
    rm $TEMP_SECRET_FILE
    
    echo "Sealed secret created successfully in $SECRET_FILE"
}

# Function to list sealed secrets
list_sealed_secrets() {
    if [ -f "$SECRET_FILE" ]; then
        echo "Sealed secrets in $ENVIRONMENT environment:"
        grep -E '^\s+[A-Z_]+:' $SECRET_FILE | sed 's/^\s*/  - /' | sed 's/:.*//'
    else
        echo "No sealed secrets file found for $ENVIRONMENT environment"
    fi
}

# Function to delete secret (manual process)
delete_secret() {
    echo "To delete a sealed secret:"
    echo "1. Manually edit $SECRET_FILE"
    echo "2. Remove the encrypted entry for the secret"
    echo "3. Recreate the sealed secret if needed"
    echo "4. Apply changes to the cluster"
}

# Main logic
case $ACTION in
    create|update)
        if [ -z "$SECRET_NAME" ] || [ -z "$SECRET_VALUE" ]; then
            echo "Error: Secret name and value are required for $ACTION action"
            usage
        fi
        create_sealed_secret "$SECRET_NAME" "$SECRET_VALUE"
        ;;
    list)
        list_sealed_secrets
        ;;
    delete)
        if [ -z "$SECRET_NAME" ]; then
            echo "Error: Secret name is required for delete action"
            usage
        fi
        delete_secret
        ;;
esac

echo ""
echo "Remember to:"
echo "1. Commit the sealed secret file to Git"
echo "2. Apply the changes using ArgoCD or kubectl"
echo "3. Restart your pods to pick up the new secrets"

# Optional: Apply the sealed secret immediately if kubectl is configured
if kubectl get namespace $NAMESPACE &> /dev/null; then
    read -p "Apply sealed secret to cluster now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl apply -f $SECRET_FILE
        echo "Sealed secret applied to cluster"
    fi
fi
