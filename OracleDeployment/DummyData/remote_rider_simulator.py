import os
import subprocess
import time
import random
import math
import sys

# Credentials come from Deployment/.env, which is NOT tracked in git. It is written either by hand or
# by fetch_secrets_from_vault.sh. This script previously embedded the Postgres password inline;
# rotating .env would then have broken it, and the quickest fix under pressure is to paste the new
# password straight back in, recreating the problem with a fresh secret. Same reasoning, and the same
# resolution, as reset_remote_db.sh and wait_for_schemas.sh alongside it.
ENV_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".env")
if os.path.isfile(ENV_FILE):
    with open(ENV_FILE, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            # Do not clobber a value the caller exported deliberately.
            os.environ.setdefault(key.strip(), value.strip())

DB_PASS = os.environ.get("POSTGRES_PASS")
if not DB_PASS:
    sys.exit("POSTGRES_PASS is not set. Populate Deployment/.env (see .env.example) or export it.")

# Configuration

# Coordinate Generation Configuration
base_lat = 12.990300
base_lng = 77.670900
rider_radius_km = 3.0

def generate_random_point(lat, lng, radius_km):
    u = random.random()
    v = random.random()
    w = radius_km / 111.0
    t = 2 * math.pi * v
    x = w * math.sqrt(u) * math.cos(t)
    y = w * math.sqrt(u) * math.sin(t)
    new_lng = x / math.cos(math.radians(lat))
    return lat + y, lng + new_lng

def run_psql(query):
    cmd = [
        "docker", "compose", "exec", "-T", "-e", f"PGPASSWORD={DB_PASS}",
        "postgres", "psql", "-h", "127.0.0.1", "-U", "postgres",
        "-d", "delivery_db", "-t", "-c", query,
    ]
    try:
        output = subprocess.check_output(cmd).decode('utf-8')
        return [line.strip() for line in output.split('\n') if line.strip()]
    except subprocess.CalledProcessError as e:
        print(f"Database query failed: {e}")
        print("Make sure you are running this script in the directory containing docker-compose.yml")
        sys.exit(1)

def run_redis(commands):
    cmd = "docker compose exec -T redis redis-cli"
    try:
        subprocess.run(cmd, input=commands.encode('utf-8'), shell=True, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Redis command failed: {e}")

def main():
    print("Fetching all riders from DB...")
    rider_ids = run_psql("SELECT id FROM delivery_executives;")
    if not rider_ids:
        print("No riders found in the database. Exiting.")
        sys.exit(0)
        
    print(f"Found {len(rider_ids)} riders. Generating static coordinates within {rider_radius_km}km radius...")

    # Assign static coordinates to each rider
    rider_locations = {}
    for r_id in rider_ids:
        lat, lng = generate_random_point(base_lat, base_lng, rider_radius_km)
        rider_locations[r_id] = (lat, lng)

    print("Starting periodic availability pings to Redis every 30 seconds. Press Ctrl+C to stop.")

    while True:
        timestamp_ms = int(time.time() * 1000)
        redis_cmds = []
        for r_id in rider_ids:
            lat, lng = rider_locations[r_id]
            
            # Update driver location, keep-alive ping, and available status
            redis_cmds.append(f"GEOADD drivers:geo:BLR {lng} {lat} {r_id}")
            redis_cmds.append(f"ZADD driver_last_ping {timestamp_ms} {r_id}")
            redis_cmds.append(f"SADD drivers:available:BLR {r_id}")
            
        commands_str = "\n".join(redis_cmds) + "\n"
        
        try:
            # Set everyone back to ONLINE in DB just in case they went offline
            run_psql("UPDATE delivery_executives SET status = 'ONLINE' WHERE status = 'OFFLINE';")
            
            # Send all commands to redis
            run_redis(commands_str)
            print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Successfully pushed static locations & pings for {len(rider_ids)} riders to Redis.", flush=True)
        except Exception as e:
            print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Error during update: {e}", flush=True)
        
        time.sleep(30)

if __name__ == '__main__':
    main()
