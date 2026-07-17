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
   *(Note: This 4-core, 24GB RAM configuration is part of the Always Free tier and is powerful enough to run the entire microservices stack).*
5. **Networking**: 
   - Ensure it creates a new Virtual Cloud Network (VCN) and a public subnet.
   - Assign a **Public IPv4 address**.
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
sudo netfilter-persistent save
```

## 4. Next Steps
Now that the server is provisioned and ports are open, proceed to run the **`02_vm_init.sh`** script on the server to install Docker, Java, and Maven.
