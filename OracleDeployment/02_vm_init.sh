#!/bin/bash
set -e

echo "======================================"
echo "  Initializing Oracle Cloud VM"
echo "======================================"

# Update packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Install standard dependencies
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common git wget unzip

# Install OpenJDK 17
echo "Installing OpenJDK 17..."
sudo apt-get install -y openjdk-17-jdk openjdk-17-jre
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64" >> ~/.bashrc

# Install Maven
echo "Installing Maven..."
sudo apt-get install -y maven

# Install Docker
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable Docker to start on boot
sudo systemctl enable docker
sudo systemctl start docker

# Add current user to docker group so sudo isn't needed for docker commands
sudo usermod -aG docker $USER

echo "=========================================================="
echo " Initialization Complete! "
echo " PLEASE LOG OUT AND LOG BACK IN for Docker permissions to apply."
echo " Or run: newgrp docker"
echo "=========================================================="
