import subprocess
import time
import random

# Configuration
SSH_KEY = "/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-07-17.key"
REMOTE_USER = "ubuntu"
REMOTE_HOST = "140.245.225.221"
COMPOSE_DIR = "Food Delivery.nosync/Deployment"
DB_PASS = "***REMOVED***"

def run_ssh_cmd(remote_cmd, input_data=None):
    cmd = [
        "ssh", "-o", "StrictHostKeyChecking=no", "-i", SSH_KEY,
        f"{REMOTE_USER}@{REMOTE_HOST}",
        remote_cmd
    ]
    if input_data:
        subprocess.run(cmd, input=input_data.encode('utf-8'), check=True)
        return ""
    else:
        output = subprocess.check_output(cmd).decode('utf-8')
        return output

def run_psql(query):
    remote_cmd = f"cd '{COMPOSE_DIR}' && docker compose exec -T -e PGPASSWORD={DB_PASS} postgres psql -h 127.0.0.1 -U postgres -d delivery_db -t -c \"{query}\""
    output = run_ssh_cmd(remote_cmd)
    return [line.strip() for line in output.split('\n') if line.strip()]

def run_redis(commands):
    remote_cmd = f"cd '{COMPOSE_DIR}' && docker compose exec -T redis redis-cli"
    run_ssh_cmd(remote_cmd, input_data=commands)

def main():
    print("Fetching all riders...")
    rider_ids = run_psql("SELECT id FROM delivery_executives;")
    print(f"Found {len(rider_ids)} riders. Starting simulation...")

    min_lat, max_lat = 12.85, 13.05
    min_lng, max_lng = 77.55, 77.75

    while True:
        timestamp_ms = int(time.time() * 1000)
        redis_cmds = []
        for r_id in rider_ids:
            # We add a small random offset so they look like they are moving slightly
            lat = random.uniform(min_lat, max_lat)
            lng = random.uniform(min_lng, max_lng)
            
            redis_cmds.append(f"GEOADD drivers:geo:BLR {lng} {lat} {r_id}")
            redis_cmds.append(f"ZADD driver_last_ping {timestamp_ms} {r_id}")
            redis_cmds.append(f"SADD drivers:available:BLR {r_id}")
            
        commands_str = "\n".join(redis_cmds) + "\n"
        
        try:
            # Set everyone back to ONLINE in DB just in case they went offline
            run_psql("UPDATE delivery_executives SET status = 'ONLINE' WHERE status = 'OFFLINE';")
            
            # Send all commands to redis via SSH
            run_redis(commands_str)
            print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Pushed locations & pings for {len(rider_ids)} riders to Redis.", flush=True)
        except Exception as e:
            print(f"Error during update: {e}", flush=True)
        
        time.sleep(30)

if __name__ == '__main__':
    main()
