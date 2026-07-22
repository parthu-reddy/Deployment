# UI Deployment Process (Oracle Cloud VM)

This document outlines the procedure to deploy updates to the React UI (`FoodDeliveryAppUI`) on the remote Oracle Cloud VM. It also serves as a log of common pitfalls and mistakes to avoid during deployment.

## Standard Deployment Steps

When modifying UI components locally and deploying them to the live Oracle VM environment, follow this sequence:

1. **Sync Local Code to Remote**
   Ensure any local file changes are actually pushed to the remote server before attempting a build.
   ```bash
   # Example: Syncing a specific file via rsync
   rsync -avz -e "ssh -o StrictHostKeyChecking=no -i /path/to/ssh-key.key" \
     "FoodDeliveryAppUI/src/components/AdminFleetMap.tsx" \
     "ubuntu@<ORACLE_IP>:~/Food Delivery.nosync/FoodDeliveryAppUI/src/components/AdminFleetMap.tsx"
   ```

2. **Build the React App Remotely**
   SSH into the remote server, navigate to the UI directory, and run the production Vite build.
   ```bash
   ssh ubuntu@<ORACLE_IP>
   cd 'Food Delivery.nosync/FoodDeliveryAppUI'
   npm run build
   ```

3. **Rebuild the NGINX Docker Container (No Cache)**
   After building the new `dist` folder, rebuild the Docker image and restart the container.
   ```bash
   cd ../Deployment
   # IMPORTANT: Use --no-cache to force Docker to copy the new dist folder
   docker compose build --no-cache food-delivery-app-ui
   docker compose up -d food-delivery-app-ui
   ```

## Lessons Learned & Mistakes to Avoid

During our deployment workflow, we ran into several issues that serve as valuable lessons:

### 1. Forgetting to Sync Code
**The Mistake:** Modifying the code locally on the Mac but expecting the remote Oracle server to magically pick up the changes.
**The Fix:** Used `rsync` to manually push the updated file (`AdminFleetMap.tsx`) across SSH to the remote VM before rebuilding.

### 2. Incorrect Docker Service Names
**The Mistake:** Running `docker compose restart food-delivery-ui`. The command failed because the actual service name defined in `docker-compose.yml` was different.
**The Fix:** Checked `docker-compose.yml` and corrected the target to `food-delivery-app-ui`.

### 3. Docker Build Cache Aggressiveness
**The Mistake:** Running `docker compose build food-delivery-app-ui`. Docker aggressively cached the `COPY dist /usr/share/nginx/html` layer. Even though `npm run build` generated fresh files, Docker saw the `COPY` instruction and assumed nothing had changed, resulting in the old code being deployed again.
**The Fix:** Appended the `--no-cache` flag (`docker compose build --no-cache food-delivery-app-ui`) to force Docker to ignore the cached layers and physically pull the new `dist` folder into the image.

### 4. Client-Side Browser Caching
**The Mistake:** Even after a successful no-cache Docker deployment, the browser continued to render the old UI because Single Page Applications (SPAs) often cache the `index.html` or old JavaScript bundles locally.
**The Fix:** Always perform a **Hard Refresh** (`Cmd + Shift + R` or `Ctrl + F5`) in the browser after a UI deployment to ensure the newest Vite chunk hashes are fetched.

### 5. Unescaped Spaces in Remote Paths
**The Mistake:** When using `rsync` or `scp` to transfer a file, the destination path had an unescaped space (e.g., `ubuntu@<IP>:~/Food Delivery.nosync/...`). The remote shell split the path at the space, causing `rsync` to mistakenly write the file to `~/Food` rather than the intended directory. As a result, the code on the remote machine was never actually updated, but the command didn't fail.
**The Fix:** Always escape spaces in remote paths or quote them correctly. Alternatively, use a foolproof pipe command if rsync escaping is tricky: `cat local_file.tsx | ssh ubuntu@<IP> "cat > 'Food Delivery.nosync/.../file.tsx'"`.
