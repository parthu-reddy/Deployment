# UI Deployment (Oracle Cloud VM)

The UI ships the same way as every other service: an image built by CI, published to OCIR, pulled
by the VM. There is no UI-specific deployment procedure any more.

```bash
# publish (normally CI does this)
Deployment/publish.sh food-delivery-app-ui

# deploy
Deployment/deploy.sh food-delivery-app-ui
```

`deploy.sh` verifies the container ends up on the intended image rather than merely reporting
healthy, and prints a reminder to hard-refresh the browser.

## One thing that is genuinely different about this service

Its Docker build context is its **own directory**, not the workspace root:

```yaml
food-delivery-app-ui:   context: ../FoodDeliveryAppUI    dockerfile: Dockerfile
customer-service:       context: ../                    dockerfile: CustomerApplication/Dockerfile
```

The UI Dockerfile does `COPY nginx.conf`, which only resolves from the UI directory; the Java
Dockerfiles do `COPY <Module>/target/*-SNAPSHOT.jar`, which only resolves from the root. This is
recorded in `Deployment/service-map.tsv` because it is not derivable, and assuming one context for
everything broke a full publish 11 images in.

## Lessons that no longer apply

The previous version of this document listed five hard-won pitfalls. Four are now unreachable and
are recorded here only so nobody reintroduces the workflow that produced them:

- **Forgetting to sync source** — the VM holds no source; it pulls an image.
- **Wrong compose service name** — `deploy.sh` validates against `service-map.tsv` and fails in a
  second with the valid list.
- **Docker caching the `COPY dist` layer**, requiring `--no-cache` — images are built on a runner
  from a clean checkout and identified by a git-sha tag, so a stale layer cannot be silently reused.
- **Unescaped spaces in remote paths** writing to `~/Food` instead of the intended directory —
  nothing rsyncs source any more.

## The one that still applies

**Hard-refresh after deploying.** Vite emits content-hashed bundles, but a browser can hold a cached
`index.html` that references the previous ones. `Cmd+Shift+R`. This is client-side and no deployment
change removes it.
