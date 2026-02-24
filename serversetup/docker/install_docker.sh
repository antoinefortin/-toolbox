#!/bin/bash

# Docker & Docker Compose Installation Script for Debian
# Author: Generated for Antoine's VPS setup
# Description: Complete installation of Docker Engine and Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

print_info "Starting Docker installation..."
echo ""

# Step 1: Remove old Docker versions
print_info "Removing old Docker versions if present..."
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
print_success "Old versions removed"
echo ""

# Step 2: Update package index
print_info "Updating package index..."
apt-get update
print_success "Package index updated"
echo ""

# Step 3: Install prerequisites
print_info "Installing prerequisites..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
print_success "Prerequisites installed"
echo ""

# Step 4: Add Docker's official GPG key
print_info "Adding Docker's GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
print_success "GPG key added"
echo ""

# Step 5: Set up the Docker repository
print_info "Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
print_success "Repository configured"
echo ""

# Step 6: Update package index again
print_info "Updating package index with Docker repository..."
apt-get update
print_success "Package index updated"
echo ""

# Step 7: Install Docker Engine and Docker Compose
print_info "Installing Docker Engine, containerd, and Docker Compose..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
print_success "Docker components installed"
echo ""

# Step 8: Enable Docker to start on boot
print_info "Enabling Docker service..."
systemctl enable docker
systemctl start docker
print_success "Docker service enabled and started"
echo ""

# Step 9: Add current user to docker group (if not root)
if [ -n "$SUDO_USER" ]; then
    print_info "Adding user '$SUDO_USER' to docker group..."
    usermod -aG docker $SUDO_USER
    print_success "User added to docker group"
    print_warning "You'll need to log out and back in for group changes to take effect"
else
    print_info "Adding 'debian' user to docker group..."
    usermod -aG docker debian 2>/dev/null && print_success "User 'debian' added to docker group" || print_warning "User 'debian' not found, skipping"
fi
echo ""

# Step 10: Verify installation
print_info "Verifying Docker installation..."
docker --version
print_success "Docker Engine installed successfully"
echo ""

print_info "Verifying Docker Compose installation..."
docker compose version
print_success "Docker Compose installed successfully"
echo ""

# Step 11: Test Docker with hello-world
print_info "Testing Docker with hello-world container..."
if docker run --rm hello-world > /dev/null 2>&1; then
    print_success "Docker test successful!"
else
    print_warning "Docker test had issues, but installation appears complete"
fi
echo ""

# Display installation summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Docker Installation Complete! 🎉                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Installed versions:"
docker --version
docker compose version
echo ""
echo "Useful commands:"
echo "  • Check Docker status:     systemctl status docker"
echo "  • View running containers: docker ps"
echo "  • View all containers:     docker ps -a"
echo "  • View images:             docker images"
echo "  • Docker Compose commands: docker compose [up|down|ps|logs]"
echo ""
print_warning "Important: If you added a user to the docker group, log out and back in for changes to take effect"
echo ""