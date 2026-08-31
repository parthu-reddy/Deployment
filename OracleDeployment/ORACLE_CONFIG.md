# Oracle Cloud Configuration

- **Public IP**: 140.245.234.137
- **SSH Private Key Path**: /Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key
- **Remote workspace**: `/home/ubuntu/Food Delivery.nosync/Deployment` — the VM holds **only** the
  `Deployment` directory. There is no source code and nothing is built here.
- **Registry**: `hyd.ocir.io/axekmbadoczl/food-delivery` (OCIR, Hyderabad)
  - `export REGISTRY=hyd.ocir.io/axekmbadoczl` before running publish/deploy.
  - The VM holds a **pull-only** credential. A push from the VM is expected to be refused by IAM.
- **Secrets**: `Deployment/.env` on the VM (mode 600), written by
  `OracleDeployment/fetch_secrets_from_vault.sh` using instance principals. It also carries
  `REGISTRY` and one `*_TAG` per service, written by `deploy.sh --sync-env`; without those the VM
  cannot resolve its own image names.
- **Profile**: `SPRING_PROFILES_ACTIVE=dev`, set in the VM's `.env`; compose defaults to `dev`.

## Gotcha: the OCI CLI is not on a non-interactive PATH

`oci` lives at `/home/ubuntu/bin/oci`. Ubuntu's default `.bashrc` returns early for non-interactive
shells, so this finds nothing:

```bash
ssh -i "$KEY" ubuntu@140.245.234.137 "oci --version"      # command not found
```

while this works:

```bash
ssh -i "$KEY" ubuntu@140.245.234.137 "bash -lc 'oci --version'"
```

The first form once led to the conclusion that the CLI was never installed. It was.
