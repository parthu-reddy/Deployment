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
Deployment/publish-config.sh <service>.yml      # ship a config and restart its consumers
Deployment/publish-config.sh --all              # ship all configs and restart all consumers
```

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
| `deploy.sh --rollback <service>` | back to the previous tag |
| `publish.sh <service>...` | build and push images only |
| `reconcile.sh` | declared vs running, plus image drift |
| `SCHEMA_POLICY.md` | migrations are immutable and forward-only |

The VM builds nothing — it holds only this `Deployment/` directory and pulls images from OCIR.
Config YAMLs are the exception: `config-service` bind-mounts this directory. Use `publish-config.sh`
to sync changes and safely restart only the services that need to read them.

---

## Key Infrastructure Components
- **Zookeeper & Kafka**: Message broker for asynchronous event-driven communication (e.g., `payment-events`, `order-events`).
- **PostgreSQL**: Relational database for core domain data (Orders, Users, Restaurants).
- **Redis**: In-memory data store for caching and temporary state (e.g., JWT blacklisting).
- **Service Configurations**: YAML files (e.g., `api-gateway.yml`, `customer-service.yml`) that are served by the `ConfigService`.

