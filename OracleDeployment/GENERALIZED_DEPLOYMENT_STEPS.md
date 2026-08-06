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

### Handling Spring Boot `jarmode=tools` Docker Extraction
When building layered Docker images with Spring Boot, the extract command varies between versions:
- In Spring Boot 3.3.x and newer: `RUN java -Djarmode=tools -jar app.jar extract --layers --launcher --destination extracted` works seamlessly.
- In Spring Boot 3.1.x and earlier: The `jarmode=tools` capability is NOT natively present in the same way, and running the `extract` command will yield: `Unsupported jarmode 'tools'`.
- **Fix Procedure:** Upgrade the `spring-boot-starter-parent` POM to a compatible version (e.g., `3.3.0`+) and the corresponding `spring-cloud-dependencies` (e.g., `2023.0.2`+) to enable the `jarmode=tools` builder inside Docker.

### Multi-Module Maven Docker Builds
When a microservice needs dependencies from other modules within the same repository (e.g., `CommonLibrary`), running the Docker build solely in the microservice directory will fail if it cannot locate the local `CommonLibrary.jar` artifact in its local `.m2`.
- **Fix Procedure:**
  1. Build the parent project using `mvn clean package -DskipTests` to generate the `.jar` files in all the respective `target` directories.
  2. Configure `docker-compose.yml` to use the parent directory as the build context (`context: ../`) and explicitly specify the dockerfile location (`dockerfile: <MicroserviceName>/Dockerfile`).
  3. The `Dockerfile` can then copy the pre-built `target/*.jar` from the build context instead of trying to run `mvn package` during the Docker build stage.
