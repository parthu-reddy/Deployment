# Remote Deployment Folder Rule

**CRITICAL SAFEGUARD**
When interacting with the remote Oracle production environment (140.245.234.137), you must **NEVER** use, sync to, or reference a directory named `FoodDelivery`. 

The correct directory for all deployment scripts, remote commands, and configuration is ALWAYS **`Food Delivery.nosync`** (e.g. `~/Food Delivery.nosync`). 

Any hardcoded references to `FoodDelivery` are incorrect and must be changed to `Food Delivery.nosync`. 
If you find yourself using `FoodDelivery` on the remote server, you are making a critical mistake and must stop and correct it.
