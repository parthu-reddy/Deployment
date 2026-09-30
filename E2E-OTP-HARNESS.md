# Dev Autofill Code and parked E2E OTP harness

**Autofill Code** is a Dev browser capability. The separate E2E runner-secret harness has no UI
control and remains parked unless an approved E2E window explicitly enables it.

## Normal Dev Autofill Code

The Dev deployment deliberately sets `DEV_OTP_ENABLED=true` in `.env.defaults` and
`.env.example`. Base Compose passes it only to `api-gateway` and `identity-service`; its Compose
fallback is `false`. The backend independently requires a `dev` profile that excludes `prod`, so a
production profile cannot enable this capability merely by receiving the environment variable.

After a normal OTP initiation, IdentityService returns `X-Dev-OTP-Available: true` only when the
restricted Dev lookup is available for the selected seeded account and server-owned portal. Gateway
CORS exposes that response header to the Dev UI. The UI reads it at runtime and retrieves the code
immediately after initiation. The existing **Autofill Code** control then fills that retrieved code
into the OTP field. This flow does not use
`E2E_RUNNER_SECRET`, the `e2e` profile, `.env.e2e`, or the E2E Compose overlay.

The Dev lookup is intentionally narrower than the historical endpoint:

- It is active only in the non-production Dev profile and when `DEV_OTP_ENABLED=true`.
- It returns a code only after normal initiation and only for a seeded phone number paired with its
  server-owned login portal.
- It neither creates users or roles nor issues a session or token. Normal OTP verification still
  enforces provisioned-role rules; customer self-registration remains the only self-registration
  path.

For manual Dev testing without SMS, select a seeded test account and request the code normally.
When the server advertises the capability, the UI retrieves the code and **Autofill Code** fills it.
If the control is unavailable, enter a real SMS code instead; do not enable the E2E harness for
ordinary developer login.

`DEV_OTP_ENABLED` is a Dev deployment setting. Production deployment must omit it or set it to
`false` and must not activate the `dev` profile. The backend profile guard is an independent
production boundary.

## Deploy Dev Autofill Code

1. Roll out the updated `api-gateway`, `identity-service`, and `food-delivery-app-ui` images
   through the normal image rollout.
2. Sync the Oracle deployment tools and defaults, the base Compose file, and the gateway
   configuration that exposes the capability header.
3. On the Oracle host, use the ordinary Vault refresh procedure, without `--with-e2e`, to
   regenerate `.env` from the synced defaults and existing Vault values. That produces
   `DEV_OTP_ENABLED=true` for the Dev profile while leaving `E2E_OTP_ENABLED=false`; Dev Autofill
   needs no new Vault secret.
4. Recreate the base `api-gateway` and `identity-service` containers after the refresh and deploy
   the current UI image through the ordinary rollout. Do not include `docker-compose.e2e.yml` or
   create `.env.e2e` for this change.

## Parked E2E runner-secret harness

The separate OTP lookup harness remains **parked by default**. The normal Compose file sets
`E2E_OTP_ENABLED=false`; missing or false settings do not create the E2E lookup controller or
gateway admission filter.

## Preconditions for a future E2E window

- OCI Vault contains a nonempty `E2E_RUNNER_SECRET` that is distinct from `IDENTITY_HMAC_SECRET`.
- The Oracle instance dynamic group can read `secret-family` in the Vault compartment.
- The current `api-gateway` and `identity-service` images, Oracle deployment support files, and
  both compose files have been deployed. From the local workspace, run:

  ```bash
  Deployment/deploy.sh --sync-oracle-tools
  Deployment/deploy.sh --sync-compose
  ```

  The first command proves the Oracle host has the `--with-e2e` Vault helper and its defaults;
  the second proves it has the overlay.
- The Java E2E runner receives the same secret through its protected CI or local test environment
  as `E2E_RUNNER_SECRET` or `-De2e.runner.secret`; do not put it in a browser, frontend build,
  checked-in file, test output, or tunnel URL.

## Future activation only

Use this only for an approved browser E2E window. The helper refuses to contact Vault unless the
same shell explicitly enables the feature. Run these commands from the deployment directory on the
Oracle host:

```bash
export E2E_OTP_ENABLED=true
export OCI_VAULT_ID=ocid1.vault.oc1...
./OracleDeployment/fetch_secrets_from_vault.sh --with-e2e
docker compose -f docker-compose.yml -f docker-compose.e2e.yml up -d --force-recreate api-gateway identity-service
```

The Vault helper creates the ignored, mode-600 `.env.e2e`. The overlay passes that file only to
`api-gateway` and `identity-service`, enables `E2E_OTP_ENABLED=true`, and activates `dev,e2e` only
in those two containers. The gateway checks the runner secret before routing the E2E request and
IdentityService checks it again before returning an OTP for an allowlisted seeded account. The
browser itself continues to use normal OTP initiate and verify requests; the Java runner obtains
its code outside the browser process. This E2E path is separate from normal Dev Autofill Code.

An ordinary successful `fetch_secrets_from_vault.sh` run removes any stale `.env.e2e` after it has
successfully replaced the base `.env`. This handles an interrupted E2E teardown without deleting
the E2E file when a base Vault refresh itself fails.

## Deactivate after the run

From the same deployment directory:

```bash
unset E2E_OTP_ENABLED
SPRING_PROFILES_ACTIVE=dev E2E_OTP_ENABLED=false docker compose -f docker-compose.yml up -d --force-recreate api-gateway identity-service
rm -f .env.e2e
```

The base Compose recreation removes the runner secret and the `e2e` profile from both containers
before the secret file is deleted. This is also the immediate teardown procedure if an earlier E2E
window is still active.
