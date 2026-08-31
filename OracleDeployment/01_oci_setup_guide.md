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

## 4. Copy the Deployment directory to the VM

The VM does **not** get the source tree. It compiles nothing: images are built on a Mac or a CI
runner, pushed to OCIR, and pulled here. What it needs is the `Deployment` directory — the compose
file, the per-service config YAMLs that `config-service` serves, and the scripts.

From your local machine:

```bash
rsync -avz -e "ssh -i path/to/your_private_key.key -o IPQoS=none -o ServerAliveInterval=15" \
  --exclude '.env' \
  --exclude 'node_modules' \
  --exclude '__pycache__' \
  --exclude '*.log' \
  "/path/to/local/Food Delivery.nosync/Deployment" \
  ubuntu@<YOUR_PUBLIC_IP>:"/home/ubuntu/Food Delivery.nosync/"
```

`.env` is excluded deliberately — it holds live credentials and is written on the VM itself by
`fetch_secrets_from_vault.sh`, so that the only plaintext copy exists there and is transient.

Two things that have gone wrong here before:

- **The space in the path.** Double-quoting the destination is NOT enough — the local shell strips
  the quotes and the remote shell splits on the space, so rsync writes to `/home/ubuntu/Food` and
  still exits 0. macOS rsync 2.6.9 has no `--protect-args`. Use single quotes locally with the space
  backslash-escaped for the remote shell:
  `'ubuntu@HOST:/home/ubuntu/Food\ Delivery.nosync/Deployment/'`. Verify with md5 on both ends; the
  exit code will not tell you.
- **Copying the whole workspace out of habit.** It transfers gigabytes the VM has no use for, and
  leaves stale source lying around that looks authoritative during an incident.

## 5. Initialize the VM

```bash
cd "Food Delivery.nosync"
chmod +x Deployment/OracleDeployment/02_vm_init.sh
./Deployment/OracleDeployment/02_vm_init.sh
```

It installs Docker, the compose plugin and the OCI CLI — no JDK, no Maven, no Node, because
nothing is built here.

## 6. Log in to the registry

The VM pulls images, so it needs a **pull-only** credential:

```bash
docker login hyd.ocir.io
```

Username is `<namespace>/<oci-username>`; the password is an auth token, not your console password.
Do not give this VM a push credential — a push from here should be refused by IAM. Images are
published from a Mac or a CI runner only.

## 7. Deploy

From the workspace root on your Mac:

```bash
export REGISTRY=hyd.ocir.io/<namespace>
Deployment/OracleDeployment/03_clean_deploy.sh
```

