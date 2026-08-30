import re

with open("docker-compose.yml", "r") as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    if line.strip() == "environment:":
        # Check if the service is postgres, zookeeper, kafka, redis, jaeger
        # We can look backwards to find the service name
        service_name = None
        for j in range(i, -1, -1):
            if lines[j].startswith("  ") and not lines[j].startswith("   ") and lines[j].strip().endswith(":"):
                service_name = lines[j].strip()[:-1]
                break
        
        if service_name not in ["postgres", "zookeeper", "kafka", "redis", "jaeger", "food-delivery-app-ui"]:
            new_lines.append("    - OTLP_ENDPOINT=http://jaeger:4318/v1/traces\n")

with open("docker-compose.yml", "w") as f:
    f.writelines(new_lines)

