# Oracle Cloud Infrastructure (OCI) Setup Guide

This guide will walk you through setting up an "Always Free" Oracle Cloud VM for deploying the Food Delivery Microservices Architecture.

## 1. Provision a Compute Instance
1. Log in to your Oracle Cloud Console.
2. Go to **Compute -> Instances** and click **Create Instance**.
3. **Name**: `food-delivery-production` (or any name you prefer).
4. **Image and Shape**:
   - **Image**: Select **Ubuntu 22.04**.
   - **Shape**: Click *Change Shape*, choose **Ampere (ARM)** -> **VM.Standard.A1.Flex**.
   - **OCPUs**: Set to **4**.
   - **Memory**: Set to **24 GB**.
   *(Note: This 4-core, 24GB RAM configuration is part of the Always Free tier. If you receive an "Out of Capacity" error, try selecting a different Availability Domain. If you are in a single-AD region, you may need to wait for capacity to free up or upgrade to a Pay-As-You-Go account to receive priority hardware allocation).*
5. **Networking**: 
   - Ensure it creates a new Virtual Cloud Network (VCN) and a public subnet.
   - Assign a **Public IPv4 address**.
   *(Troubleshooting: If the Public IPv4 toggle is disabled with a warning about needing a public subnet, do not create the VCN here. Instead, open a new tab, go to Networking -> Virtual Cloud Networks, use the "Start VCN Wizard" to "Create VCN with Internet Connectivity", and then return to the instance creation page to select your new VCN).*
6. **SSH Keys**: 
   - Click **Save Private Key** to download your `.key` file. You will need this to connect to your VM.
7. Click **Create**. Wait until the instance status turns green (`RUNNING`).
8. Copy the **Public IP Address** shown on the Instance Details page.

## 2. Configure VCN Security List (Open Ports)
By default, Oracle Cloud blocks all incoming traffic except SSH (port 22). We need to open ports for the API Gateway and Frontend UI.
1. On your Instance Details page, click on the **Subnet** link under *Primary VNIC*.
2. Click on the **Security List** associated with the subnet (usually named `Default Security List for...`).
3. Click **Add Ingress Rules**:
   - **Source CIDR**: `0.0.0.0/0` (Allow from anywhere)
   - **IP Protocol**: TCP
   - **Destination Port Range**: `8080` (API Gateway)
   - Click **Add Ingress Rules**.
4. Repeat the process to add another Ingress Rule:
   - **Source CIDR**: `0.0.0.0/0`
   - **IP Protocol**: TCP
   - **Destination Port Range**: `80` (React Frontend / Nginx)
3. Repeat again for **Port 8761** if you want to access the Eureka Server dashboard.

*(Note: Depending on how you deploy your UI, you may also want to open `8086`, `8081` etc if you intend to hit microservices directly without going through the API gateway, but it's recommended to route everything through port 8080).*

## 3. Configure VM Firewall (iptables / firewalld)
Oracle's Ubuntu images often come with `iptables` rules that block traffic even if the VCN is open.
Connect to your VM using SSH:
```bash
chmod 400 your_private_key.key
ssh -i your_private_key.key ubuntu@<YOUR_PUBLIC_IP>
```

Run these commands to open ports locally on the VM:
```bash
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 8080 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 8761 -j ACCEPT
sudo netfilter-persistent save
```

## 4. Transfer Source Code to the VM
The Ubuntu Minimal image strips out almost all utilities. The most robust way to get your code onto the server is by securely copying it from your local machine using `rsync`, while explicitly ignoring heavy build artifacts.

1. **Install rsync on the server**:
   In your SSH terminal, run:
   ```bash
   sudo apt-get update && sudo apt-get install -y rsync
   ```

2. **Transfer files from your local machine**:
   Open a *new* terminal on your local machine (do not close the SSH session) and run this highly optimized `rsync` command. It includes specific flags to prevent macOS SSH packet timeouts (`IPQoS`, `ServerAliveInterval`) and excludes massive directories to ensure a lightning-fast transfer:
   ```bash
   rsync -avz -e "ssh -i path/to/your_private_key.key -o IPQoS=none -o ServerAliveInterval=15" \
     --exclude 'target' \
     --exclude 'node_modules' \
     --exclude '.git' \
     --exclude '.github' \
     --exclude 'dist' \
     --exclude 'build' \
     --exclude '.DS_Store' \
     --exclude '.npm-cache' \
     --exclude '.idea' \
     --exclude '.vscode' \
     --exclude '*.iml' \
     --exclude '*.log' \
     --exclude 'customer_logs*.txt' \
     --exclude 'apache-maven-*' \
     "/path/to/local/Food Delivery.nosync" ubuntu@<YOUR_PUBLIC_IP>:/home/ubuntu/
   ```

## 5. Initialize the VM
Once the file transfer is complete, return to your server's SSH terminal, navigate into the newly copied directory, and run the initialization script to install Java, Maven, and Docker:

```bash
cd "Food Delivery.nosync"
chmod +x Deployment/OracleDeployment/02_vm_init.sh
./Deployment/OracleDeployment/02_vm_init.sh
```

*(Note: The initialization script will instruct you to reload your group permissions using `newgrp docker` at the very end before running the final deployment script).*
