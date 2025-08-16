#!/bin/bash

# Setup script for Linux/macOS environments
# This script installs kubeseal and sets up the environment

set -e

echo "🚀 Setting up SmartRent Deploy for Linux/macOS..."

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

case $OS in
    Linux*)
        OS_TYPE="linux"
        ;;
    Darwin*)
        OS_TYPE="darwin"
        ;;
    *)
        echo "❌ Unsupported OS: $OS"
        exit 1
        ;;
esac

case $ARCH in
    x86_64)
        ARCH_TYPE="amd64"
        ;;
    arm64|aarch64)
        ARCH_TYPE="arm64"
        ;;
    *)
        echo "❌ Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "📋 Detected OS: $OS_TYPE, Architecture: $ARCH_TYPE"

# Check if kubeseal is already installed
if command -v kubeseal &> /dev/null; then
    CURRENT_VERSION=$(kubeseal --version 2>&1 | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    echo "✅ kubeseal is already installed (version: $CURRENT_VERSION)"
    read -p "Do you want to reinstall/update kubeseal? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⏭️  Skipping kubeseal installation"
        INSTALL_KUBESEAL=false
    else
        INSTALL_KUBESEAL=true
    fi
else
    echo "📥 kubeseal not found, will install"
    INSTALL_KUBESEAL=true
fi

if [ "$INSTALL_KUBESEAL" = true ]; then
    # Get latest version
    echo "🔍 Getting latest kubeseal version..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep -o '"tag_name": "[^"]*' | grep -o '[^"]*$')
    
    if [ -z "$LATEST_VERSION" ]; then
        echo "❌ Failed to get latest version, using v0.24.0"
        LATEST_VERSION="v0.24.0"
    fi
    
    echo "📦 Installing kubeseal $LATEST_VERSION..."
    
    # Download kubeseal
    DOWNLOAD_URL="https://github.com/bitnami-labs/sealed-secrets/releases/download/$LATEST_VERSION/kubeseal-$LATEST_VERSION-$OS_TYPE-$ARCH_TYPE.tar.gz"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    echo "⬇️  Downloading from: $DOWNLOAD_URL"
    curl -sL "$DOWNLOAD_URL" | tar xz
    
    # Install to /usr/local/bin (requires sudo) or ~/bin
    if [ -w "/usr/local/bin" ]; then
        mv kubeseal /usr/local/bin/
        echo "✅ kubeseal installed to /usr/local/bin/kubeseal"
    elif [ -d "$HOME/bin" ]; then
        mv kubeseal "$HOME/bin/"
        echo "✅ kubeseal installed to $HOME/bin/kubeseal"
        echo "💡 Make sure $HOME/bin is in your PATH"
    else
        mkdir -p "$HOME/bin"
        mv kubeseal "$HOME/bin/"
        echo "✅ kubeseal installed to $HOME/bin/kubeseal"
        echo "💡 Add $HOME/bin to your PATH: export PATH=\$HOME/bin:\$PATH"
    fi
    
    # Clean up
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    # Verify installation
    if command -v kubeseal &> /dev/null; then
        echo "✅ kubeseal installation verified: $(kubeseal --version)"
    else
        echo "⚠️  kubeseal installed but not in PATH. You may need to restart your shell or update PATH"
    fi
fi

# Check kubectl
if command -v kubectl &> /dev/null; then
    echo "✅ kubectl is available"
else
    echo "⚠️  kubectl not found. Please install kubectl to manage Kubernetes resources"
    echo "   Installation guide: https://kubernetes.io/docs/tasks/tools/"
fi

# Make scripts executable
echo "🔧 Setting up scripts..."
chmod +x scripts/manage-secrets.sh
echo "✅ Scripts are now executable"

# Check if sealed-secrets controller is installed
echo "🔍 Checking sealed-secrets controller..."
if kubectl get deployment sealed-secrets-controller -n kube-system &> /dev/null; then
    echo "✅ Sealed-secrets controller is installed"
elif kubectl get deployment sealed-secrets-controller -n sealed-secrets &> /dev/null; then
    echo "✅ Sealed-secrets controller is installed"
else
    echo "⚠️  Sealed-secrets controller not found"
    read -p "Install sealed-secrets controller now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📦 Installing sealed-secrets controller..."
        kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
        echo "✅ Sealed-secrets controller installed"
    else
        echo "⏭️  Skipped sealed-secrets controller installation"
        echo "   Install later with: kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml"
    fi
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📚 Quick start:"
echo "   List secrets:    ./scripts/manage-secrets.sh dev list"
echo "   Create secret:   ./scripts/manage-secrets.sh dev create MYSQL_PASSWORD mypassword"
echo "   Update secret:   ./scripts/manage-secrets.sh dev update API_KEY new-key"
echo ""
echo "🔗 Useful commands:"
echo "   Test Helm chart: helm template charts/smartrent/ --values charts/smartrent/environments/dev/values.yaml"
echo "   Lint chart:      helm lint charts/smartrent/"
echo "   Apply ArgoCD:    kubectl apply -f apps/dev-application.yaml"
echo ""
echo "💡 Note: Windows users can use scripts/kubeseal.exe and scripts/manage-secrets.ps1"
