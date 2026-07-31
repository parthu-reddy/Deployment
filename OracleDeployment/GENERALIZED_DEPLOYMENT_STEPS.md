# Generalized Deployment Steps & Learnings

## Oracle Cloud Deployment

### Dealing with Compilation Errors on Remote
When running deployment scripts that `rsync` the local codebase to a remote VM (like `03_deploy_dev.sh`), if a file is deleted or renamed locally, `rsync` by default does not delete the remote file. This leaves "orphaned" or "stale" `.java` files on the remote server which can cause compilation errors during the maven build inside Docker (e.g. `PickedUpState.java` still existing on the remote while being deleted locally).

**Fix Procedure:**
1. Identify the stale files in the remote build logs (`COMPILATION ERROR`).
2. Add the `--delete` flag to the `rsync` command within the deployment script to ensure the remote directory strictly mirrors the local directory.
   - Example: `rsync -avz --delete --exclude 'target' --exclude 'node_modules' ...`
3. If necessary, clean the remote environment using `docker system prune -af` and `docker compose down -v` to ensure no stale cached layers interfere with the fresh build.
4. Rerun the deployment script.

### Handling Space Issues
Remote VMs (like the Oracle instance) might run out of space due to accumulating dangling Docker images and stopped containers.
- Always prune system artifacts if builds start failing inexplicably or if space seems constrained:
  ```bash
  docker compose down -v
  docker system prune -af --volumes
  ```
