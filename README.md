# Deployment

## The three commands

```bash
export REGISTRY=hyd.ocir.io/axekmbadoczl     # once per terminal
```

**1. Deploy one service** (builds, publishes, deploys — backend or UI, same command):

```bash
Deployment/ship.sh customer-service
Deployment/ship.sh food-delivery-app-ui
Deployment/ship.sh --fresh customer-service     # also recreate the container from scratch
Deployment/ship.sh --no-build customer-service  # jar already current, skip the build
```

**2. Deploy everything:**

```bash
Deployment/OracleDeployment/03_clean_deploy.sh          # keeps the databases
Deployment/OracleDeployment/03_clean_deploy.sh --wipe   # destroys volumes too, prompts first
```

**3. Config:**

```bash
Deployment/deploy.sh --config --dry-run application-dev.yml api-gateway.yml api-gateway-dev.yml identity-service-dev.yml
Deployment/deploy.sh --config application-dev.yml api-gateway.yml api-gateway-dev.yml identity-service-dev.yml
```

`deploy.sh --config` checks that the requested profile matches the Oracle VM, publishes each file
with checksum verification, then restarts its config consumers one at a time and waits for health.
`application-dev.yml` is shared by the application services, so it triggers a reviewed restart of
all Spring config clients. Profile-specific service files such as `api-gateway-dev.yml` map to the
same consumer as their base file. `publish-config.sh` is the lower-level upload-only command; it
does not restart services.

**4. Dummy data:**

```bash
Deployment/dummy-data.sh              # wipe databases, let Flyway rebuild, then load
Deployment/dummy-data.sh --load-only  # load into existing schemas
```

Measured on 2026-08-31: one backend service 1m27s, the UI 45s, all 20 services 20s when the images
are already current, dummy data 3m14s.

### The rest

| | |
|---|---|
| `deploy.sh <service>...` | pull and start on the VM (what `ship.sh` calls) |
| `deploy.sh --sync-compose [--fresh] <service>...` | explicitly sync Compose, then recreate selected services when wiring changed |
| `deploy.sh --rollback <service>` | back to the previous tag |
| `publish.sh <service>...` | build and push images only |
| `reconcile.sh` | declared vs running, plus image drift |
| `SCHEMA_POLICY.md` | migrations are immutable and forward-only |

The VM builds nothing — it holds only this `Deployment/` directory and pulls images from OCIR.
Config YAMLs are separate from images: `config-service` bind-mounts this directory. Use
`deploy.sh --config` to sync config changes and restart the consumers. The full clean-deploy script
publishes the config bundle and recreates its service waves so they load the current profile files.
Compose is separate:
`deploy.sh` refuses service deployment when its local and remote copies differ; use
`--sync-compose --fresh` for the affected service. The full clean-deploy script performs that sync
before starting any container.

---

## Key Infrastructure Components
- **Zookeeper & Kafka**: Message broker for asynchronous event-driven communication (e.g., `payment-events`, `order-events`).
- **PostgreSQL**: Relational database for core domain data (Orders, Users, Restaurants).
- **Redis**: In-memory data store for caching and temporary state (e.g., JWT blacklisting).
- **Service Configurations**: YAML files (e.g., `api-gateway.yml`, `customer-service.yml`) that are served by the `ConfigService`.



<!-- dummy data update -->
