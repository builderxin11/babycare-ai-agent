#!/bin/bash
# EC2 Setup Script for NurtureMind
# Run this on a fresh Amazon Linux 2023 or Ubuntu 22.04 instance

set -e

echo "=== NurtureMind EC2 Setup ==="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS"
    exit 1
fi

echo "Detected OS: $OS"

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        echo "Docker already installed"
        return
    fi

    echo "Installing Docker..."

    if [ "$OS" = "amzn" ]; then
        # Amazon Linux 2023
        sudo dnf update -y
        sudo dnf install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
    elif [ "$OS" = "ubuntu" ]; then
        # Ubuntu
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker $USER
    fi

    echo "Docker installed successfully"
}

# Install Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        echo "Docker Compose already installed"
        return
    fi

    echo "Installing Docker Compose..."

    if [ "$OS" = "amzn" ]; then
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    # Ubuntu already has docker-compose-plugin from above

    echo "Docker Compose installed successfully"
}

# Setup project directory
setup_project() {
    echo "Setting up project directory..."

    PROJECT_DIR="/opt/nurturemind"
    sudo mkdir -p $PROJECT_DIR
    sudo chown $USER:$USER $PROJECT_DIR

    echo "Project directory: $PROJECT_DIR"
}

# Setup cron for health check
setup_cron() {
    echo "Setting up health check cron..."

    # Create log directory
    sudo mkdir -p /var/log/nurturemind
    sudo chown $USER:$USER /var/log/nurturemind

    # Add cron job (every 5 minutes)
    (crontab -l 2>/dev/null | grep -v "health-check.sh"; echo "*/5 * * * * /opt/nurturemind/deploy/scripts/health-check.sh") | crontab -

    echo "Health check cron configured"
}

# Configure firewall
configure_firewall() {
    echo "Configuring firewall..."

    if [ "$OS" = "amzn" ]; then
        # Amazon Linux uses security groups, no local firewall by default
        echo "Using AWS Security Groups for firewall"
    elif [ "$OS" = "ubuntu" ]; then
        sudo ufw allow 8000/tcp   # FastAPI
        sudo ufw allow 6081/tcp   # Web VNC (Desktop)
        sudo ufw allow 443/tcp    # HTTPS (if using nginx)
        sudo ufw allow 80/tcp     # HTTP
        echo "UFW rules configured"
    fi
}

# Main
install_docker
install_docker_compose
setup_project
configure_firewall

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Log out and log back in (for docker group)"
echo "2. Clone your repo to /opt/nurturemind"
echo "3. Copy .env.example to .env and fill in values"
echo "4. Run: cd /opt/nurturemind/deploy && docker-compose up -d"
echo "5. Access web VNC at http://YOUR_EC2_IP:6081 to login to Xiaohongshu"
echo ""
echo "Make sure your EC2 Security Group allows:"
echo "  - Port 8000 (API)"
echo "  - Port 6081 (Web VNC for XHS login)"
echo "  - Port 443/80 (if using HTTPS)"
