#!/usr/bin/env bash
#
# Provision a fresh Oracle Cloud VM to RUN the platform. It does not build it.
#
# No JDK, no Maven, no Node. The VM holds no source code and compiles nothing: images are built on
# a Mac or a CI runner, pushed to OCIR, and pulled here. Installing a toolchain would only invite
# someone to build on a 4-core box and wonder why it takes an hour.
set -euo pipefail

echo "======================================"
echo "  Initializing Oracle Cloud VM"
echo "======================================"

sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common \
    git wget unzip rsync

echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker "$USER"

# Needed by fetch_secrets_from_vault.sh, which runs HERE and authenticates as this instance
# (instance principals) rather than with an API key on disk.
echo "Installing the OCI CLI..."
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" \
    -- --accept-all-defaults

# The installer puts oci in ~/bin and appends the PATH export to ~/.bashrc. Ubuntu's default
# .bashrc returns early for non-interactive shells, so `ssh vm "oci ..."` will NOT find it even
# though `ssh vm` then `oci ...` works. That difference cost real debugging time -- it looked
# exactly like the CLI was never installed. ~/.profile is read by login shells, so add it there
# too and invoke remote commands with `ssh vm "bash -lc '...'"`.
if ! grep -q 'HOME/bin' ~/.profile 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.profile
fi

echo "=========================================================="
echo " Initialization complete."
echo
echo " Two things must still be done BY HAND on this VM:"
echo
echo "  1. Log out and back in (or: newgrp docker) for the docker group to apply."
echo
echo "  2. Log in to the registry with a PULL-ONLY credential:"
echo "       docker login hyd.ocir.io"
echo "     Username: <namespace>/<oci-username>   Password: an auth token"
echo "     This VM must not hold a push credential. A push from here is expected to be"
echo "     refused by IAM -- images are published from a Mac or a CI runner only."
echo
echo " Then, from the workspace root on your Mac:"
echo "   export REGISTRY=hyd.ocir.io/<namespace>"
echo "   Deployment/OracleDeployment/03_clean_deploy.sh"
echo "=========================================================="
